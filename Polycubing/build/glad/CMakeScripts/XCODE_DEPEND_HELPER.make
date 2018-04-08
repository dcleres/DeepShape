# DO NOT EDIT
# This makefile makes sure all linkable targets are
# up-to-date with anything they link to
default:
	echo "Do not invoke directly"

# Rules to remove targets that are older than anything to which they
# link.  This forces Xcode to relink the targets from scratch.  It
# does not seem to check these dependencies itself.
PostBuild.glad.Debug:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/Debug/libglad.a


PostBuild.glad.Release:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/Release/libglad.a


PostBuild.glad.MinSizeRel:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/MinSizeRel/libglad.a


PostBuild.glad.RelWithDebInfo:
/Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a:
	/bin/rm -f /Users/davidcleres/DeepShape/libigl-example-project/build/glad/RelWithDebInfo/libglad.a




# For each target create a dummy ruleso the target does not have to exist
