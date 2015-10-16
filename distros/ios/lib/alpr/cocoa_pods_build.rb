require 'fileutils'
require 'logger'
require_relative 'core_build'
require_relative 'utils'

module Alpr
  class CocoaPodsBuild < CoreBuild

    def get_cmake_args(builddir, target)
      super(builddir, target).push(
        "-DOPENALPR_DEP_COCOA_PODS_PATH=#{builddir}/Pods"
      )
    end

    def build_deps(builddir, target, arch)

      xcodeproj_file = File.join(builddir, "src.xcodeproj/project.pbxproj")

      execute("xcproj touch")

      # Install Tesseract and OpenCV CocoaPods
      #    if !File.exist?(File.join(builddir, 'Podfile'))
      FileUtils.cp(File.join(CONFIG_DIR, 'Podfile'), builddir)
      #      execute('pod install')
      #    end

      #execute("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=8.0 -parallelizeTargets ARCHS=#{arch} -jobs 8 -sdk #{target.downcase} -configuration Release -target cocoapod_setup")
      execute("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=8.0 ARCHS=#{arch} -sdk #{target.downcase} -configuration Release -target cocoapod_setup")

      FileUtils.cp(xcodeproj_file, "#{xcodeproj_file}.orig")
      Alpr::Xcode.rewrite_project_file!(xcodeproj_file)

      #FileUtils.ln_s(File.join(builddir, 'Pods', 'OpenCV','opencv2.framework','Headers/'), File.join(alt_headers_path, 'opencv2'))
      #FileUtils.ln_s(File.join(builddir, 'Pods', 'TesseractOCRiOS','TesseractOCR','include'), File.join(alt_headers_path, 'opencv2'))
    end

    #  "constructs the framework directory after all the targets are built"
    def self.put_framework_together(srcroot, dstroot)

      # find the list of targets (basically, ["iPhoneOS", "iPhoneSimulator"])
      targetlist = Dir[(File.join(dstroot, "build", "*"))].map { |t| File.basename(t) }

      # set the current dir to the dst root
      currdir = FileUtils.pwd()
      framework_dir = dstroot + "/openalpr.framework"
      if File.directory?(framework_dir)
        FileUtils.rm_rf(framework_dir)
        FileUtils.mkdir_p(framework_dir)
        FileUtils.cd(framework_dir)

        # form the directory tree
        dstdir = "Versions/A"
        FileUtils.mkdir_p(dstdir + "/Resources")

        tdir0 = "../build/" + targetlist[0]
        # copy headers
        FileUtils.cp_r(tdir0 + "/install/include/openalpr", dstdir + "/Headers")

        # make universal static lib

        wlist = targetlist.map { |t| "../build/" + t + "/lib/Release/libopencv_world.a"  }.join(" ")
        #wlist = " ".join(["../build/" + t + "/lib/Release/libopencv_world.a" for t in targetlist])
        execute("lipo -create " + wlist + " -o " + dstdir + "/openalpr")

        # copy Info.plist
        FileUtils.cp(tdir0 + "/ios/Info.plist", dstdir + "/Resources/Info.plist")

        # make symbolic links
        FileUtils.ln_s("A", "Versions/Current")
        FileUtils.ln_s("Versions/Current/Headers", "Headers")
        FileUtils.ln_s("Versions/Current/Resources", "Resources")
        FileUtils.ln_s("Versions/Current/openalpr", "openalpr")
      end
    end

  end

end
