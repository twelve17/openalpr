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

#include "alpr.h"
#include "alpr_impl.h"

namespace alpr
{

  // ALPR code

  Alpr::Alpr(const std::string country, const std::string configFile, const std::string runtimeDir)
  {
    impl = new AlprImpl(country, configFile, runtimeDir);
  }

  Alpr::~Alpr()
  {
    delete impl;
  }

  AlprResults Alpr::recognize(std::string filepath)
  {

    std::ifstream ifs(filepath.c_str(), std::ios::binary|std::ios::ate);
    std::ifstream::pos_type pos = ifs.tellg();

    std::vector<char>  buffer(pos);

    ifs.seekg(0, std::ios::beg);
    ifs.read(&buffer[0], pos);

    return this->recognize( buffer );
  }

  AlprResults Alpr::recognize(std::vector<char> imageBytes)
  {
    std::vector<AlprRegionOfInterest> regionsOfInterest;
    return impl->recognize(imageBytes, regionsOfInterest);
  }

  AlprResults Alpr::recognize(unsigned char* pixelData, int bytesPerPixel, int imgWidth, int imgHeight, std::vector<AlprRegionOfInterest> regionsOfInterest)
  {
    return impl->recognize(pixelData, bytesPerPixel, imgWidth, imgHeight, regionsOfInterest);
  }

  std::string Alpr::toJson( AlprResults results )
  {
    return AlprImpl::toJson(results);
  }

  AlprResults Alpr::fromJson(std::string json) {
    return AlprImpl::fromJson(json);
  }


  void Alpr::setDetectRegion(bool detectRegion)
  {
    impl->setDetectRegion(detectRegion);
  }

  void Alpr::setTopN(int topN)
  {
    impl->setTopN(topN);
  }

  void Alpr::setDefaultRegion(std::string region)
  {
    impl->setDefaultRegion(region);
  }

  bool Alpr::isLoaded()
  {
    return impl->isLoaded();
  }

  std::string Alpr::getVersion()
  {
    return AlprImpl::getVersion();
  }


}