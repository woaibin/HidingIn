# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles/HidingIn_autogen.dir/AutogenUsed.txt"
  "CMakeFiles/HidingIn_autogen.dir/ParseCache.txt"
  "HidingIn_autogen"
  )
endif()
