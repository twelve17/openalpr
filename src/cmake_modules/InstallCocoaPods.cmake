MESSAGE(INFO, "Creating symlink in dir $ENV{OPENCV_POD_DIR}")

execute_process(
  COMMAND pod install 
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  RESULT_VARIABLE POD_INSTALL_RESULT
  OUTPUT_VARIABLE POD_INSTALL_OUTPUT
)

MESSAGE(INFO, "Result: ${POD_INSTALL_RESULT}, Output: ${POD_INSTALL_OUTPUT}")

execute_process(
  COMMAND ${CMAKE_COMMAND} 
  -E make_directory 
  $ENV{OPENCV_POD_INCLUDE_DIR} 
)

execute_process(
  COMMAND ${CMAKE_COMMAND} 
  -E create_symlink 
  "$ENV{OPENCV_POD_DIR}/Headers/" 
  "$ENV{OPENCV_POD_INCLUDE_DIR}/opencv2" 
)
