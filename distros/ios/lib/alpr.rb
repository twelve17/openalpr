require_relative './alpr/cocoa_pods_build'
require_relative './alpr/manual_deps_build'
require_relative './alpr/xcode'
require_relative './alpr/core_build'

# Dir Strucures:
#
# - $openalpr_root_dir
#   |- $src_root (src)
#   |- $config_dir (distros/ios)
#
# - $dest_root:
#   |- Xcode
#   |    |- Pods
#   |    |- Headers
#   |    |- Libraries
#   |    |- openalpr
#   |- $work_dir (work)
#   |    |- tesseract-x.y.z.tar.gz
#   |    |- tesseract-x.y.z
#   |    |- $build_root (build)
#   |         |- $build_dir
#   |              |- per_arch_output
#   |              |- merged_output
#   |- openalpr.framework/
#   |    |- <todo>
#   |- build.log

module Alpr
end
