/*
 * Copyright (c) 2014 New Designs Unlimited, LLC
 * Opensource Automated License Plate Recognition [http://www.openalpr.com]
 *
 * This file is part of OpenAlpr.
 *
 * OpenAlpr is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License
 * version 3 as published by the Free Software Foundation
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include "platemask.h"

using namespace std;
using namespace cv;

namespace alpr
{

  PlateMask::PlateMask(PipelineData* pipeline_data) {
    this->pipeline_data = pipeline_data;
    this->hasPlateMask = false;

  }


  PlateMask::~PlateMask() {
  }

  cv::Mat PlateMask::getMask() {
    return this->plateMask;
  }

  void PlateMask::findOuterBoxMask( vector<TextContours > contours )
  {
    double min_parent_area = pipeline_data->config->templateHeightPx * pipeline_data->config->templateWidthPx * 0.10;	// Needs to be at least 10% of the plate area to be considered.

    int winningIndex = -1;
    int winningParentId = -1;
    int bestCharCount = 0;
    double lowestArea = 99999999999999;

    if (pipeline_data->config->debugCharAnalysis)
      cout << "CharacterAnalysis::findOuterBoxMask" << endl;

    for (unsigned int imgIndex = 0; imgIndex < contours.size(); imgIndex++)
    {
      //vector<bool> charContours = filter(thresholds[imgIndex], allContours[imgIndex], allHierarchy[imgIndex]);

      int charsRecognized = 0;
      int parentId = -1;
      bool hasParent = false;
      for (unsigned int i = 0; i < contours[imgIndex].goodIndices.size(); i++)
      {
        if (contours[imgIndex].goodIndices[i]) charsRecognized++;
        if (contours[imgIndex].goodIndices[i] && contours[imgIndex].hierarchy[i][3] != -1)
        {
          parentId = contours[imgIndex].hierarchy[i][3];
          hasParent = true;
        }
      }

      if (charsRecognized == 0)
        continue;

      if (hasParent)
      {
        double boxArea = contourArea(contours[imgIndex].contours[parentId]);
        if (boxArea < min_parent_area)
          continue;

        if ((charsRecognized > bestCharCount) ||
            (charsRecognized == bestCharCount && boxArea < lowestArea))
          //(boxArea < lowestArea)
        {
          bestCharCount = charsRecognized;
          winningIndex = imgIndex;
          winningParentId = parentId;
          lowestArea = boxArea;
        }
      }
    }

    if (pipeline_data->config->debugCharAnalysis)
      cout << "Winning image index (findOuterBoxMask) is: " << winningIndex << endl;

    if (winningIndex != -1 && bestCharCount >= 3)
    {
      int longestChildIndex = -1;
      double longestChildLength = 0;
      // Find the child with the longest permiter/arc length ( just for kicks)
      for (unsigned int i = 0; i < contours[winningIndex].size(); i++)
      {
        for (unsigned int j = 0; j < contours[winningIndex].size(); j++)
        {
          if (contours[winningIndex].hierarchy[j][3] == winningParentId)
          {
            double arclength = arcLength(contours[winningIndex].contours[j], false);
            if (arclength > longestChildLength)
            {
              longestChildIndex = j;
              longestChildLength = arclength;
            }
          }
        }
      }

      Mat mask = Mat::zeros(pipeline_data->thresholds[winningIndex].size(), CV_8U);

      // get rid of the outline by drawing a 1 pixel width black line
      drawContours(mask, contours[winningIndex].contours,
                   winningParentId, // draw this contour
                   cv::Scalar(255,255,255), // in
                   CV_FILLED,
                   8,
                   contours[winningIndex].hierarchy,
                   0
                  );

      // Morph Open the mask to get rid of any little connectors to non-plate portions
      int morph_elem  = 2;
      int morph_size = 3;
      Mat element = getStructuringElement( morph_elem, Size( 2*morph_size + 1, 2*morph_size+1 ), Point( morph_size, morph_size ) );

      //morphologyEx( mask, mask, MORPH_CLOSE, element );
      morphologyEx( mask, mask, MORPH_OPEN, element );

      //morph_size = 1;
      //element = getStructuringElement( morph_elem, Size( 2*morph_size + 1, 2*morph_size+1 ), Point( morph_size, morph_size ) );
      //dilate(mask, mask, element);

      // Drawing the edge black effectively erodes the image.  This may clip off some extra junk from the edges.
      // We'll want to do the contour again and find the larges one so that we remove the clipped portion.

      vector<vector<Point> > contoursSecondRound;

      findContours(mask, contoursSecondRound, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
      int biggestContourIndex = -1;
      double largestArea = 0;
      for (unsigned int c = 0; c < contoursSecondRound.size(); c++)
      {
        double area = contourArea(contoursSecondRound[c]);
        if (area > largestArea)
        {
          biggestContourIndex = c;
          largestArea = area;
        }
      }

      if (biggestContourIndex != -1)
      {
        mask = Mat::zeros(pipeline_data->thresholds[winningIndex].size(), CV_8U);

        vector<Point> smoothedMaskPoints;
        approxPolyDP(contoursSecondRound[biggestContourIndex], smoothedMaskPoints, 2, true);

        vector<vector<Point> > tempvec;
        tempvec.push_back(smoothedMaskPoints);
        //fillPoly(mask, smoothedMaskPoints.data(), smoothedMaskPoints, Scalar(255,255,255));
        drawContours(mask, tempvec,
                     0, // draw this contour
                     cv::Scalar(255,255,255), // in
                     CV_FILLED,
                     8,
                     contours[winningIndex].hierarchy,
                     0
                    );
      }

      if (pipeline_data->config->debugCharAnalysis)
      {
        vector<Mat> debugImgs;
        Mat debugImgMasked = Mat::zeros(pipeline_data->thresholds[winningIndex].size(), CV_8U);

        pipeline_data->thresholds[winningIndex].copyTo(debugImgMasked, mask);

        debugImgs.push_back(mask);
        debugImgs.push_back(pipeline_data->thresholds[winningIndex]);
        debugImgs.push_back(debugImgMasked);

        Mat dashboard = drawImageDashboard(debugImgs, CV_8U, 1);
        displayImage(pipeline_data->config, "Winning outer box", dashboard);
      }

      hasPlateMask = true;
      this->plateMask = mask;
    }

    hasPlateMask = false;
    Mat fullMask = Mat::zeros(pipeline_data->thresholds[0].size(), CV_8U);
    bitwise_not(fullMask, fullMask);

    this->plateMask = fullMask;
  }

}