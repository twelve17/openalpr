require 'osx/plist'
require_relative 'utils'

module Alpr
  class Xcode
    extend Utils

    PUBLIC_HEADERS_PREFIX = '${PODS_ROOT}/Headers/Public'

    OPENCV_PREFIX = 'OpenCV'

    OPENCV_HEADERS =  [
      "",
      "opencv2",
      "opencv2/calib3d",
      "opencv2/contrib",
      "opencv2/core",
      "opencv2/features2d",
      "opencv2/flann",
      "opencv2/highgui",
      "opencv2/imgproc",
      "opencv2/legacy",
      "opencv2/ml",
      "opencv2/nonfree",
      "opencv2/objdetect",
      "opencv2/photo",
      "opencv2/stitching",
      "opencv2/stitching/detail",
      "opencv2/video",
      "opencv2/videostab",
      "opencv2/world"
    ].map { |x| x.empty? ? OPENCV_PREFIX : File.join(OPENCV_PREFIX, x) }

    OTHER_HEADERS = [ "" ]

    PUBLIC_HEADERS = (OTHER_HEADERS + OPENCV_HEADERS).map do |x|
      '"' +
        (x.empty? ? PUBLIC_HEADERS_PREFIX : File.join(PUBLIC_HEADERS_PREFIX, x)) +
        '"'
    end

    def self.rewrite_project_file!(pfile)

      if !File.exists?(pfile)
        warn "File does not exist: #{pfile}"
        return
      end

      plist = OSX::PropertyList.load(File.new(pfile))

      plist['objects'].each do |id,ref|
        if ref['isa'] == "XCBuildConfiguration" && (bs = ref['buildSettings'])
          #if bs.has_key?('HEADER_SEARCH_PATHS')
          #  bs['HEADER_SEARCH_PATHS'] = bs['HEADER_SEARCH_PATHS'].reject { |x| x.include?('opencv') }.concat(PUBLIC_HEADERS)
          #  bs['LIBRARY_SEARCH_PATHS'] = ["$(inherited)"]
          #end

          if bs.has_key?('OTHER_LDFLAGS')
            #if (bs['OTHER_LDFLAGS'].is_a?(Array) && !bs['OTHER_LDFLAGS'].map { |x| x.include?('opencv') }.empty?
            #bs['OTHER_LDFLAGS'].include?('opencv')
            if bs['OTHER_LDFLAGS'].nil?
              bs['OTHER_LDFLAGS'] = "-ObjC "
            elsif bs['OTHER_LDFLAGS'].is_a?(Array)
              bs['OTHER_LDFLAGS'] << "-ObjC"
            else
              bs['OTHER_LDFLAGS'] += "-ObjC "
            end
          end

          if bs.has_key?('GCC_C_LANGUAGE_STANDARD')
            binding.pry
          else
            bs['GCC_C_LANGUAGE_STANDARD'] = 'gnu99'
          end

          if bs.has_key?('CLANG_CXX_LANGUAGE_STANDARD')
            binding.pry
          else
            bs['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++0x'
          end

          #if bs.has_key?('LIBRARY_SEARCH_PATHS') && !bs['LIBRARY_SEARCH_PATHS'].empty?
          #end

        end
      end

      # writes to XML, does not support old plist format
      OSX::PropertyList.dump_file(pfile, plist)

      # re-convert to old plist format :(
      execute("xcproj -p #{File.dirname(pfile)} touch")
    end

  end
end


