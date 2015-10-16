require_relative 'utils'
require 'fileutils'

module Alpr
  class CoreBuild
    include Utils # needed for instance level calls to execute
    #extend Utils # needed for class level calls to execute
    #extend Utils

    IOS_BASE_SDK="9.0"
    IOS_DEPLOY_TGT="9.0"

    OPENALPR_ROOT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..'))

    CONFIG_DIR = File.join(OPENALPR_ROOT_DIR, 'distros', 'ios')

    BUILD_TARGETS = {
      "armv7" => "iPhoneOS",
      "armv7s" => "iPhoneOS",
      "arm64" => "iPhoneOS",
      "i386" => "iPhoneSimulator",
      "x86_64" => "iPhoneSimulator"
    }

    # for some reason, if you do not specify CMAKE_BUILD_TYPE, it puts libs to "RELEASE" rather than "Release"
    CMAKE_BASE_ARGS = [
      "-GXcode",
      "-DCMAKE_CONFIGURATION_TYPES=Release",
      #"-DCMAKE_CONFIGURATION_TYPES=Debug;Release",
      #-DCMAKE_CONFIGURATION_TYPES:STRING=Debug;Release
      #"-DCMAKE_BUILD_TYPE=Release",
      '-DCMAKE_C_FLAGS="-Wno-implicit-function-declaration"',
      "-DCMAKE_INSTALL_PREFIX=install",
      "-DWITH_DAEMON=OFF",
      "-DWITH_UTILITIES=OFF",
      "-DWITH_BINDING_JAVA=OFF",
      "-DWITH_BINDING_PYTHON=OFF",
      "-DWITH_GPU_DETECTOR=OFF",
      "-DWITH_TESTS=OFF",
    ]


    def log_execute(cmd, env={}, opts={})
      execute(cmd, env, {log: self.log_file})
    end

    # "main function to do all the work"
    def build_framework(dest_root)
      self.dest_root = dest_root
      self.work_dir = File.join(dest_root, "work")
      self.build_root_dir = File.join(work_dir, "build")

      [self.dest_root, self.work_dir, self.build_root_dir].each do |dir|
        FileUtils.mkdir_p(dir)
      end

      self.log_file = File.join(self.dest_root, "build.log")
      self.logger = Logger.new(self.log_file)
      self.logger.level = Logger::INFO
      puts "Logging shell output to #{self.log_file}"

      puts "Using build_root #{self.build_root_dir}"

      BUILD_TARGETS.each do |arch, target|
        self.build_alpr_and_dependencies(target, arch)
      end

      self.put_framework_together(dest_root)
    end

    protected

    attr_accessor :log_file, :logger, :dest_root, :work_dir, :build_root_dir, :rebuild_deps

    def initialize(opts={})
      opts.each { |k,v| self.send("#{k}=", v) }
      self.rebuild_deps = true if self.rebuild_deps.nil?
    end

    def alpr_src_dir
      File.join(OPENALPR_ROOT_DIR, 'src')
    end

    def get_cmake_args(build_dir, target)
      CMAKE_BASE_ARGS.concat([
        #"-DCMAKE_BUILD_TYPE=Release-#{target}",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_TOOLCHAIN_FILE=#{File.join(CONFIG_DIR, 'cmake', 'Toolchains', "Toolchain-#{target}_Xcode.cmake")}",
      ])
    end

    def configure_build(build_dir, target)
      cmakeargs = self.get_cmake_args(build_dir, target).join(" ")

      # if cmake cache exists, just rerun cmake to update OpenALPR.xcodeproj if necessary
      #if File.file?(File.join(build_dir, "CMakeCache.txt"))
      #  execute("cmake #{cmakeargs} ")
      #else
      #  binding.pry
      #end

      log_execute("make clean || echo 'nothing to clean'")
      #FileUtils.mv("#{self.alpr_src_dir}/CMakeLists.txt #{self.alpr_src_dir}/CMakeLists.txt.orig")
      log_execute("cmake #{cmakeargs} #{self.alpr_src_dir}")
    end

    def build_deps(build_dir, target, arch)
      raise "Subclass must implement."
    end

    def get_build_dir(target, arch)
      File.join(self.build_root_dir, target + '-' + arch)
    end

    def setup_build_dir(build_dir)
      if self.rebuild_deps
        FileUtils.rm_rf(build_dir)
      end

      if !File.directory?(build_dir)
        FileUtils.mkdir_p(build_dir)
      end
    end

    def get_xcodebuild_args(target, arch)
      args = [
        "-parallelizeTargets",
        "-jobs 8",
        "-sdk #{target.downcase}",
        "-configuration Release",
        "IPHONEOS_DEPLOYMENT_TARGET=#{IOS_DEPLOY_TGT}",
        "ARCHS=#{arch}",
      ]
    end

    def run_xcodebuild(target, arch)
      ["-target ALL_BUILD", "-target install"].each do |cmake_target|
      ##["-target Release", "-target install install"].each do |cmake_target|
      #["-target ALL_BUILD"].each do |cmake_target|
      #["-target Release", "-target install install"].each do |cmake_target|
        log_execute("xcodebuild #{self.get_xcodebuild_args(target, arch).push(cmake_target).join(" ")}")
      end
    end

    def do_in_dir(dir)
      currdir = FileUtils.pwd
      FileUtils.cd(dir)
      yield
      FileUtils.cd(currdir)
    end

    def build_alpr(build_dir, target, arch)
      self.configure_build(build_dir, target)
      self.build_deps(build_dir, target, arch)
      self.run_xcodebuild(target, arch)
    end

    #  "builds OpenALPR for device or simulator"
    def build_alpr_and_dependencies(target, arch)
      build_dir = self.get_build_dir(target, arch)
      puts "building openalpr for target #{target}, arch #{arch}, on #{build_dir}"
      self.setup_build_dir(build_dir)
      self.do_in_dir(build_dir) do
        self.build_alpr(build_dir, target, arch)
      end
      #execute("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=8.0 -parallelizeTargets ARCHS=#{arch} -jobs 8 -sdk #{target.downcase} -configuration Release -target ALL_BUILD")
      #execute("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=#{IOS_DEPLOY_TGT} -parallelizeTargets ARCHS=#{arch} -jobs 8 -sdk #{target.downcase} -configuration Release -target alpr")
      #execute("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=#{IOS_DEPLOY_TGT} ARCHS=#{arch} -sdk #{target.downcase} -configuration Release -target install install")

    end

  end
end


