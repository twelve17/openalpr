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

#ifndef TEXTCONTOURS_H
#define	TEXTCONTOURS_H

#include <vector>
#include "opencv2/imgproc/imgproc.hpp"

namespace alpr
{

  class TextContours {
  public:
    TextContours();
    TextContours(cv::Mat threshold);
    virtual ~TextContours();

    void load(cv::Mat threshold);

    int width;
    int height;

    std::vector<bool> goodIndices;
    std::vector<std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;

    unsigned int size();
    int getGoodIndicesCount();

    std::vector<bool> getIndicesCopy();
    void setIndices(std::vector<bool> newIndices);

    cv::Mat drawDebugImage();
    cv::Mat drawDebugImage(cv::Mat baseImage);

  private:


  };

}

#endif	/* TEXTCONTOURS_H */

