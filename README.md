# DeepShape
Deep learning on 3d meshes via model simplification

The success of various applications in vision and robotics demand a structured and simplified representation of the 3D input solid models.
Poly-cube mapping, inspired by the nature of human perception of 3D shapes as a collection of simple parts, can provide regular and simple representations for general solid models. Obtaining such simplified representations efficiently is however still an open challenge, as current state-of-the-art algorithms are still far away from real-time performance.
The goal of this project is to explore how poly-cube model simplification can be utilized to perform deep learning on 3d meshes efficiently: in particular the student will implement a poly-cube mapping algorithm and create a data-set of simplified models with it. Once such data-set is created 3D CNNs can be exploited to obtain efficient solid model simplification.

In this repository I implemented a C++ solution for Polycube Generation starting from an .stl file. The input file is first processed by alignment of the triangular meshes with the axis of the 3D domain. This is archived by clicking several times on the space bar of your computer. Once the perfect shape is generated the user can save generated model via hiting the "s" button of the Keyboard. Finally this "rectangulized" shape of the car (or what so ever) can be voxelized by clicking on the "v" button. The voxelization does not appear on screen but is saved immidiately in the output files and can be visualized by the viewvox plug-in.
