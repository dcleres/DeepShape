# DO NOT EDIT
# This makefile makes sure all linkable targets are
# up-to-date with anything they link to
default:
	echo "Do not invoke directly"

# Rules to remove targets that are older than anything to which they
# link.  This forces Xcode to relink the targets from scratch.  It
# does not seem to check these dependencies itself.
PostBuild.Polycubes_bin.Debug:
PostBuild.igl_core.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.igl_opengl_glfw.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.igl_opengl.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.igl_core.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.igl_common.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.glad.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
PostBuild.glfw.Debug: /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin
/Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin:\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Debug/libglfw3.a
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/Debug/Polycubes_bin


PostBuild.glad.Debug:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a


PostBuild.glfw.Debug:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Debug/libglfw3.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Debug/libglfw3.a


PostBuild.Polycubes_bin.Release:
PostBuild.igl_core.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.igl_opengl_glfw.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.igl_opengl.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.igl_core.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.igl_common.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.glad.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
PostBuild.glfw.Release: /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin
/Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin:\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Release/libglfw3.a
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/Release/Polycubes_bin


PostBuild.glad.Release:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a


PostBuild.glfw.Release:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Release/libglfw3.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Release/libglfw3.a


PostBuild.Polycubes_bin.MinSizeRel:
PostBuild.igl_core.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.igl_opengl_glfw.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.igl_opengl.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.igl_core.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.igl_common.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.glad.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
PostBuild.glfw.MinSizeRel: /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin
/Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin:\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/MinSizeRel/libglfw3.a
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/MinSizeRel/Polycubes_bin


PostBuild.glad.MinSizeRel:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a


PostBuild.glfw.MinSizeRel:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/MinSizeRel/libglfw3.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/MinSizeRel/libglfw3.a


PostBuild.Polycubes_bin.RelWithDebInfo:
PostBuild.igl_core.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.igl_opengl_glfw.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.igl_opengl.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.igl_core.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.igl_common.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.glad.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
PostBuild.glfw.RelWithDebInfo: /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin
/Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin:\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a\
	/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/RelWithDebInfo/libglfw3.a
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/RelWithDebInfo/Polycubes_bin


PostBuild.glad.RelWithDebInfo:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a


PostBuild.glfw.RelWithDebInfo:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/RelWithDebInfo/libglfw3.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/RelWithDebInfo/libglfw3.a




# For each target create a dummy ruleso the target does not have to exist
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Debug/libglfw3.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/MinSizeRel/libglfw3.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/RelWithDebInfo/libglfw3.a:
/Users/davidcleres/DeepShape/libigl-example-project/build/glfw/src/Release/libglfw3.a:
