/*
 * voxelizerMain.cpp
 *
 *  Created on: 1 Jul, 2014
 *      Author: chenqian
 */
#include "voxelizer.h"

int main(int args, char* argv[]) {
	Timer timer;

	//Fixed grid size each time
	int gridSize = 100; //Cf Edoardo's ML file
	int numThread = 4; //atoi(argv[2]);
	string inputFile = "../../../data/pseudo_camaro.stl";
	string outputFileForView = "../../../data/kawada-hironx.binvox";
    string outputFileWrite = "../../../data/kawada-hironx-compressed.vox";
    string outputFileWriteSimple = "../../../data/kawada-hironx-simple.vox";

    timer.Restart();
	Voxelizer voxelizer(gridSize, inputFile, true);
	timer.Stop();
	cout << "voxelizer initialization "; timer.PrintTimeInS();
	cout << "-------------------------------------------" << endl;
	timer.Restart();
	voxelizer.VoxelizeSurface(numThread);
	timer.Stop();
	cout << "surface voxelization "; timer.PrintTimeInS();
	cout << "-------------------------------------------" << endl;
	timer.Restart();
	voxelizer.VoxelizeSolid(numThread);
	timer.Stop();
	cout << "solid voxelization "; timer.PrintTimeInS();
	cout << "-------------------------------------------" << endl;
	timer.Restart();

    voxelizer.buildBinaryTensor();

	voxelizer.WriteSimple(outputFileWriteSimple);    //Enables to write a file in the vox format
    voxelizer.Write(outputFileWrite);               //With simple compression
	voxelizer.WriteForView(outputFileForView);     //Enables to write a file in the binvox format

	voxelizer.writeTextFile();
    voxelizer.writeSliceTextFile(45);
    voxelizer.writeVotingToTextFile(voxelizer.voting());
    voxelizer.writeSliceVotingTextFile(45, voxelizer.voting());

	timer.Stop();
	cout << "writing file "; timer.PrintTimeInS();
	cout << "-------------------------------------------" << endl;
}

