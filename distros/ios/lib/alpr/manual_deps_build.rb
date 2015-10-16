# This is a Ruby port of this script:
#
# http://tinsuke.wordpress.com/2011/11/01/how-to-compile-and-use-tesseract-3-01-on-ios-sdk-5/
#
# It has been updated with the following:
# - amd64 build support
# - pointers to new locations of XCode toolchains
# - additional header files for Tesseract 3.03-rc1
#
# It was tested with iOS 8.0 base target, on Mavericks.

require 'fileutils'
require 'find'
require 'logger'
require_relative 'core_build'
require_relative 'utils'

module Alpr
  class ManualDepsBuild < CoreBuild
    #include Utils # needed for instance level calls to execute
    extend Utils # needed for class level calls to execute

    def self.qexec(cmd)
      execute(cmd, nil, {quiet: true})
    end

    def self.xcfind(path)
      qexec("xcrun -find #{path}")
    end

    XCODE_DEVELOPER = "/Applications/Xcode.app/Contents/Developer"
    XCODETOOLCHAIN = "#{XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"
    SDK_IPHONEOS = qexec("xcrun --sdk iphoneos --show-sdk-path")
    SDK_IPHONESIMULATOR = qexec("xcrun --sdk iphonesimulator --show-sdk-path")

    BUILD_PLATFORMS=%w{i386 armv7 armv7s arm64 x86_64}

    TESSERACT_HEADERS = %w{
      api/apitypes.h api/baseapi.h
      ccmain/pageiterator.h ccmain/mutableiterator.h ccmain/ltrresultiterator.h ccmain/resultiterator.h
      ccmain/thresholder.h ccstruct/publictypes.h
      ccutil/errcode.h ccutil/genericvector.h ccutil/helpers.h
      ccutil/host.h ccutil/ndminx.h ccutil/ocrclass.h
      ccutil/platform.h ccutil/tesscallback.h ccutil/unichar.h
    }

    LEPTON_LIB="leptonica-1.71"
    LEPTON_LIB_URL="http://www.leptonica.org/source/#{LEPTON_LIB}.tar.gz"
    TESSERACT_LIB="tesseract-3.03"
    TESSERACT_LIB_URL='https://drive.google.com/uc?id=0B7l10Bj_LprhSGN2bTYwemVRREU&export=download'

    AR = xcfind("ar")
    CXX = xcfind("c++")
    CC = xcfind("cc")
    LD = xcfind("ld")
    AS = xcfind("as")
    NM = xcfind("nm")
    RANLIB = xcfind("ranlib")

    protected

    #  "builds OpenALPR for device or simulator"
    def off_build_alpr_and_dependencies(build_root, target, arch, clean=true)
      build_dir = self.get_build_dir(build_root, target, arch)
      puts "building openalpr for target #{target}, arch #{arch}, on #{build_dir}"
      self.do_in_dir(build_dir) do
        self.build_alpr(build_dir, target, arch)
      end
    end

    def get_cmake_args(build_dir, target)
       tess_include_dir = File.join(self.global_outdir, 'include', 'tesseract')

       tess_include_dirs = %w{
         Tesseract_INCLUDE_BASEAPI_DIR
         Tesseract_INCLUDE_CCSTRUCT_DIR
         Tesseract_INCLUDE_CCMAIN_DIR
         Tesseract_INCLUDE_CCUTIL_DIR
         Tesseract_INCLUDE_DIRS
         Tesseract_PKGCONF_INCLUDE_DIRS
       }.map do |k|
         "-D#{k}=#{tess_include_dir}"
       end
       super(build_dir, target).concat(tess_include_dirs).concat(
         [
           #          "-DTesseract_INCLUDE_DIRS=#{File.join(self.global_outdir, 'include', 'tesseract')}",
#          "-DTesseract_PKGCONF_INCLUDE_DIRS=#{File.join(self.global_outdir, 'include', 'tesseract')}",
          "-DTesseract_LIB=#{File.join(self.global_outdir, 'lib', 'libtesseract_all.a')}",
          "-DLeptonica_LIB=#{File.join(self.global_outdir, 'lib', 'liblept.a')}"
        ]
      )
    end

    def build_alpr(build_dir, target, arch)
      self.local_outdir = File.join(build_dir, "per_arch_output")
      self.global_outdir = File.join(build_dir, "merged_output")

      self.build_deps(build_dir, target, arch)
      self.configure_build(build_dir, target)
      self.run_xcodebuild(target, arch)
    end

    #-----------------------------------------------------------------------------
    def build_deps(build_dir, target, arch)
      if self.rebuild_deps || !self.built?
        self.download
        self.install_leptonica
        self.install_tesseract
      end
    end

    attr_accessor :local_outdir, :global_outdir

#    def initialize(opts={})
#      opts.each { |k,v| self.send("#{k}=", v) }
#      [:work_dir, :local_outdir, :log_file].each do |arg|
#        raise "missing arg #{arg}" if arg.empty?
#        raise "disallowed #{arg}: #{opts[arg]}" if %w{ / /usr /lib /root }.include?(opts[arg])
#      end
#      self.log_file ||= File.join(self.work_dir, "build.log")
#      if self.logger.nil?
#        self.logger = Logger.new(self.log_file)
#        self.logger.level = Logger::INFO
#      end
#      puts "Logging shell output to #{self.log_file}"
#    end

    #-----------------------------------------------------------------------------
    def leptonica_lib_dir
      File.join(self.work_dir, LEPTON_LIB)
    end

    #-----------------------------------------------------------------------------
    def tesseract_lib_dir
      File.join(self.work_dir, TESSERACT_LIB)
    end

    #-----------------------------------------------------------------------------
    def download
      FileUtils.cd(self.work_dir)

      if !File.exists?("#{self.work_dir}/#{LEPTON_LIB}.tar.gz")
        puts "Downloading leptonica library."
        log_execute("curl -o #{self.work_dir}/#{LEPTON_LIB}.tar.gz #{LEPTON_LIB_URL}")
      end
      if !File.directory?(self.leptonica_lib_dir)
        log_execute("tar -xvf #{self.work_dir}/#{LEPTON_LIB}.tar.gz")
      end

      if !File.exists?("#{self.work_dir}/#{TESSERACT_LIB}.tar.gz")
        puts "Downloading tesseract library."
        log_execute("curl -L -o #{self.work_dir}/#{TESSERACT_LIB}.tar.gz #{TESSERACT_LIB_URL}")
      end
      if !File.directory?(self.tesseract_lib_dir)
        log_execute("tar -xvf #{self.work_dir}/#{TESSERACT_LIB}.tar.gz")
      end

      [self.tesseract_lib_dir, self.leptonica_lib_dir].each do |src_dir|
        if !File.directory?(src_dir)
          raise "Missing source directory: #{src_dir}"
        end
      end
    end

    #-----------------------------------------------------------------------------
    def cleanup_output
      FileUtils.rm_rf(self.local_outdir)
      FileUtils.mkdir_p(BUILD_PLATFORMS.map { |x| File.join(self.local_outdir, x) })
    end

    #-----------------------------------------------------------------------------
    def cleanup_source
      %w{clean distclean}.each { |t| log_execute("make #{t} 2> /dev/null || echo \"Nothing to #{t}\"") }
    end

    #-----------------------------------------------------------------------------
    def do_standard_build(platform, build_args)
      build_env = env_for_platform(platform)
      if build_env['BUILD_HOST_NAME']
        build_args.unshift("--host=#{build_env['BUILD_HOST_NAME']}")
      end
      log_execute("./configure #{build_args.join(' ')} && make -j12 2>&1", build_env)
    end

    #-----------------------------------------------------------------------------
    # xcrun -sdk iphoneos lipo -info $(FILENAME)
    #-----------------------------------------------------------------------------
    def create_outdir_lipo

      template_platform = 'i386'

      Find.find(File.join(self.local_outdir, template_platform)) do |template_lib_name|
        next unless File.basename(template_lib_name) =~ /^lib.+\.a$/

          fat_lib = template_lib_name.gsub(/#{template_platform}\/?/, '')
          lipo_args = ["-arch #{template_platform} #{template_lib_name}"]

        BUILD_PLATFORMS.each do |platform|
          next if platform == template_platform
          lib_name = template_lib_name.gsub(template_platform, platform)
          if File.exists?(lib_name)
            lipo_args << "-arch #{platform} #{lib_name}"
          else
            warn "********* WARNING: lib doesn't exist! #{FileUtils.pwd}/#{lib_name}"
          end
        end

        lipo_args = lipo_args.join(' ')

        self.logger.info("LIPOing libs with args: #{lipo_args}")
        lipoResult=`xcrun -sdk iphoneos lipo #{lipo_args} -create -output #{fat_lib} 2>&1`
        if lipoResult =~ /fatal error/
          raise "Got fatal error during LIPO: #{lipoResult}"
        end
      end
    end

    #-----------------------------------------------------------------------------
    def env_for_platform(platform)

      sdk_root = platform.start_with?('arm') ? SDK_IPHONEOS : SDK_IPHONESIMULATOR
      if !File.exists?(sdk_root) #&& !File.symlink?(sdk_root)
        raise "SDKROOT does not exist: #{sdk_root}"
      end

      cflags = [
        "-I#{self.global_outdir}/include",
        "-arch #{platform}",
        "-pipe",
        "-no-cpp-precomp",
        "-isysroot #{sdk_root}",
        "-miphoneos-version-min=#{IOS_DEPLOY_TGT}",
      ]
      if platform.start_with?('arm')
        cflags << "-I#{sdk_root}/usr/include/"
      end
      cflags = cflags.join(' ')

      env = {
        'SDKROOT' => sdk_root,
        'CXX' => CXX,
        'CC' => CC,
        'LD' => LD,
        'AS' => AS,
        'AR' => AR,
        'NM' => NM,
        'RANLIB' => RANLIB,
        'LDFLAGS' => "-L#{sdk_root}/usr/lib/ -L#{self.global_outdir}/lib",
        'CFLAGS' => cflags,
        'CPPFLAGS' => cflags,
        'CXXFLAGS' => cflags,
        'PATH' => "#{XCODETOOLCHAIN}/usr/bin:#{ENV['PATH']}",
      }

      if platform.start_with?('arm')
        env['BUILD_HOST_NAME'] = platform.sub(/^armv?(.+)/, 'arm-apple-darwin\1')
      end

      env
    end

    #-----------------------------------------------------------------------------
    # Merges distinct *.a archive libraries into a single one by pulling out all
    # .o files from the individual archives and stuffing them into the target archive.
    #
    # Show symbols:
    # nm -gU  libtesseract.a  | grep GetIterator
    #-----------------------------------------------------------------------------
    def merge_libfiles(platform_output_dir, merged_lib_name)

      currdir = FileUtils.pwd

      tmpDir="#{platform_output_dir}.tmp"
      FileUtils.mkdir(tmpDir)
      FileUtils.chdir(tmpDir)

      Find.find(platform_output_dir) do |path|
        next unless File.basename(path) =~ /^lib.+\.a$/
          # extract all *.o files from .a library
          log_execute("#{AR} -x #{path} `#{AR} -t #{path} | grep '.o$'`")
        # replace or add all *.o files to new lib archive
        log_execute("#{AR} -r #{File.join(platform_output_dir, merged_lib_name)} *.o")
      end

      # clean up
      FileUtils.chdir(currdir)
      FileUtils.rm_f(Dir["#{tmpDir}/*"])
      FileUtils.rmdir(tmpDir)
    end

    #-----------------------------------------------------------------------------
    def install_leptonica

      puts "Installing Leptonica"

      FileUtils.chdir(self.work_dir)
      self.cleanup_output

      BUILD_PLATFORMS.each do |platform|
        puts "Building Leptonica for #{platform}"
        FileUtils.chdir(self.leptonica_lib_dir)
        self.cleanup_source
        self.do_standard_build(platform, %w{--enable-shared=no --disable-programs --without-zlib --without-libpng --without-jpeg --without-giflib --without-libtiff})
        FileUtils.cp_r(Dir['src/.libs/lib*.a'], File.join(self.local_outdir, platform))
      end

      self.create_outdir_lipo

      # copy headers
      FileUtils.mkdir_p("#{self.global_outdir}/include/leptonica")
      FileUtils.cp_r(Dir["#{self.leptonica_lib_dir}/src/*.h"], "#{self.global_outdir}/include/leptonica")

      # copy libs
      FileUtils.mkdir_p("#{self.global_outdir}/lib")
      FileUtils.cp_r(Dir["#{self.local_outdir}/lib*.a"], "#{self.global_outdir}/lib")
    end

    def built?
      File.exists?("#{self.global_outdir}/include/leptonica") &&
        File.exists?("#{self.global_outdir}/include/tesseract")
    end

    #-----------------------------------------------------------------------------
    def install_tesseract

      puts "Installing Tesseract"

      FileUtils.chdir(self.work_dir)
      self.cleanup_output

      BUILD_PLATFORMS.each do |platform|
        puts "Building Tesseract for #{platform}"
        FileUtils.chdir(self.tesseract_lib_dir)
        self.cleanup_source
        log_execute('bash autogen.sh', self.env_for_platform(platform))
        self.do_standard_build(platform, ["--enable-shared=no", "LIBLEPT_HEADERSDIR=#{self.global_outdir}/include/"])

        #for i in `find . -name "lib*.a" | grep -v arm`; do cp -rvf $i $LOCAL_OUTDIR/$platform; done
        Find.find(self.tesseract_lib_dir) do |path|
          next unless File.basename(path) =~ /^lib.+\.a$/ && !path.include?('arm')
          FileUtils.cp_r(path, File.join(self.local_outdir, platform))
        end
        self.merge_libfiles(File.join(self.local_outdir, platform), 'libtesseract_all.a')
      end

      FileUtils.chdir(self.tesseract_lib_dir)

      self.create_outdir_lipo

      # copy headers
      FileUtils.mkdir_p("#{self.global_outdir}/include/tesseract")
      TESSERACT_HEADERS.each do |header|
        FileUtils.cp_r(header, "#{self.global_outdir}/include/tesseract")
      end

      # copy libs
      FileUtils.mkdir_p("#{self.global_outdir}/lib")
      FileUtils.cp_r(Dir["#{self.local_outdir}/lib*.a"], "#{self.global_outdir}/lib")

      self.cleanup_source
    end

  end
end

