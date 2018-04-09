# DeepShape
Deep learning on 3d meshes via model simplification

The success of various applications in vision and robotics demand a structured and simplified representation of the 3D input solid models.
Poly-cube mapping, inspired by the nature of human perception of 3D shapes as a collection of simple parts, can provide regular and simple representations for general solid models. Obtaining such simplified representations efficiently is however still an open challenge, as current state-of-the-art algorithms are still far away from real-time performance.
The goal of this project is to explore how poly-cube model simplification can be utilized to perform deep learning on 3d meshes efficiently: in particular the student will implement a poly-cube mapping algorithm and create a data-set of simplified models with it. Once such data-set is created 3D CNNs can be exploited to obtain efficient solid model simplification.

In this repository I implemented a C++ solution for Polycube Generation starting from an .stl file. The input file is first processed by alignment of the triangular meshes with the axis of the 3D domain. This is archived by clicking several times on the space bar of your computer. Once the perfect shape is generated the user can save generated model via hiting the "s" button of the Keyboard. Finally this "rectangulized" shape of the car (or what so ever) can be voxelized by clicking on the "v" button. The voxelization does not appear on screen but is saved immidiately in the output files and can be visualized by the viewvox plug-in.

# What you need to Install 

# libigl example project

A blank project example showing how to use libigl and cmake. Feel free and
encouraged to copy or fork this project as a way of starting a new personal
project using libigl.

## Compile

Compile this project using the standard cmake routine:

    mkdir build
    cd build
    cmake ..
    make

This should find and build the dependencies and create a `example_bin` binary.

## Run

From within the `build` directory just issue:

    ./example_bin

A glfw app should launch displaying a 3D cube.

## Dependencies

The only dependencies are stl, eigen, [libigl](libigl.github.io/libigl/) and
the dependencies of the `igl::opengl::glfw::Viewer`.

We recommend you to install libigl using git via:

    git clone https://github.com/libigl/libigl.git
    cd libigl/
    git checkout 6ebc585611d27d8e2038bbbf9cb4910c51713848
    git submodule update --init --recursive
    cd ..

If you have installed libigl at `/path/to/libigl/` then a good place to clone
this library is `/path/to/Polycubing/`.

## Overview


----------

This project voxelizes the meshes in STL file ***without*** the condition of *watertight*. ***It supports stl files only now.*** Basically, the project can be summarized into two steps:

- Surface voxelization  
    For each piece of mesh (triangle) , we check the collided voxels in either way: 
    1. Get the minimal bounding box of each triangle, check each voxel in this box with the triangle;
    2. Start at any voxel collided with the triangle, and do bfs search to check neighboring voxels.   
    
    The first way is lightweight, but may become worse when the ratio of (triangle's volume/bounding box's volume) is small. While the second way has quite large constant overhead. For each thread in thread pool, it will pick a triangle to voxelize. The time complexity is O(m*c), where m is the triangle number and c is some factor such as the voxel number in the bounding box or constant overhead of bfs.
- Solid voxelization  
    When equipped with surface voxelization, the solid voxelization can be simple: flood fill. We try to flood fill the outer space of the meshes like carving the wood, since it is more simple and doesn't requires *watertight* property. However, the basic flood fill with bfs is too heavy and time-consuming, optimizations are proposed here (see below). The time complexity is O(n), where n is the voxel number in the bounding box of whole mesh.
 
	- [TODO] Combine the coarse and fine strategy, i.e., do coarse grid size first to filter more unnecessary voxels.
- [TODO] Use gpu

## Installation


----------

This project requires libraries (dependencies) as follows:

- *boost*
- *libfcl* 		
	for collision checking (https://github.com/flexible-collision-library/fcl, version: tags/0.3.3), ***libccd*** is required
- *assimp*  
    for loading STL file (https://github.com/assimp/assimp)
- *cmake & make*


CMakeLists.txt is used to generate makefiles. To build this project, in command line, run

``` cmake
mkdir build
cd build
cmake ..
```

Next, in linux, use `make` in 'build' directory to compile the code. 

## How to Use


----------


- Input
	- grid_size  
	e.g., 100
	- number_of_threads  
	e.g., 4
	- stl_file  
	e.g., kawada-hironx.stl
	- output_file  
	e.g., kawada-hironx.vox
- Output (voxel file format, it is wrote in ***bianry*** mode, the 'TestVox.cpp' in test folder provides a sample code to load the .vox file.)
	- header
		- grid_size   
		one integer denotes the size of grid system, e.g., 256
		- lowerbound_x lowerbound_y lowerbound_z  
		three doubles denote the lower bound of the original system, e.g., -0.304904 -0.304904 -0.304904
		- voxel_size   
		one double denotes the unit size of a voxel in original system, e.g., 0.00391916
	- data
		- x y z  
		three integers denote the voxel coordinate in grid system, e.g, 30 66 194
        - ...   
When we have the voxel (x,y,z), we can get the box in original space as follows: (lowerbound_x + x\*voxel_size, lowerbound_y + y\*voxel_size, lowerbound_z + z\*voxel_size), (lowerbound_x + (x+1)\*voxel_size, lowerbound_y + (y+1)\*voxel_size, lowerbound_z + (z+1)\*voxel_size).

When you are in 'build' directory, a running example is: 

```./bin/voxelizer 256 4 ../data/kawada-hironx.stl ../data/kawada-hironx.vox```



For your reference, the pseudo output code for output is:

```C++
ofstream* output = new ofstream(pFile.c_str(), ios::out | ios::binary);
*output << grid_size << endl;
*output << lowerbound_x << " " << lowerbound_y << " " << lowerbound_z << endl;
*output << voxel_size << endl;
for (x,y,z) in voxels:
	*output << x << " " << y << " " << z << endl;
```
		


<!--	- header
		- $x_{grid\_size}y_{grid\_size}z_{grid\_size}$
		three integer denote the grid sizes, e.g., 256 256 256
		- $x_{lb}y_{lb}z_{lb}$  
		three doubles denote the lower bounds of the original space, e.g., -0.304904 -0.304904 -0.304904
		- $x_{vox\_unit}y_{vox\_unit}z_{vox\_unit}$  
		three doubles denote the a voxel's size in original space, e.g., 0.00783833 0.00783833 0.00783833
		- $x_{vox\_lb}$$y_{vox\_lb}$$z_{vox\_lb}$
		three integers denote the lower bound of minimal bounding box in voxelized space, e.g., 30 0 8
        - $x_{vox\_size}$$y_{vox\_size}$$z_{vox\_size}$
		three integers denote the minimal bounding box's size in voxelized space, e.g., 
	- data	
		- $value_{01}count_{[0,255]}$...  
		Recall that the voxels are stored in binary string, such as '1110000'. To reduce the output file, please be noted only voxels in the minimal bounding box for mesh are output. It is further compressed as $value$ and $count$. For '1110000', it is compressed to (1)(2)(0)(3), (1)(2) means 3 consecutive 1, and (0)(3) means 4 consecutive 0. I use two bytes to record $value$ and $count$. Specifically, $value$ can be 0 or 1, and $count$ can be [0,255] which corresponds to [1,256]. To retrieve the coordination of a voxel in original space, let $(x,y,z)$ denote the voxel coordinate extracted from the output binary string, and the coordinate in voxelized space is $(x+x_{vox\_lb},y+y_{vox\_lb},z+z_{vox\_lb})$.
-->



## Directories


----------



