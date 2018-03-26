/*
 * voxelizerMain.cpp
 *
 *  Created on: 1 Jul, 2014
 *      Author: chenqian
 */
#include "voxelizer.h"

int main(int args, char* argv[]) {
	Timer timer;
//	string fileName = "../data/kawada-hironx.stl";
//	string fileName2 = "../data/test.binvox";
	if (args == 5) {        // DELETE THIS LINE !!!!!!!!!!!!!!!!!!!!!
		//QUERY WHILE LAUNCHING THE PROGRAMM
		int gridSize = atoi(argv[1]);
		int numThread = atoi(argv[2]);
		string inputFile = argv[3];
		string outputFile = argv[4];

		/*//Fixed grid size each time
		int gridSize = 100; //Cf Edoardo's ML file
		int numThread = 4; //atoi(argv[2]);
		string inputFile = "../data/kawada-hironx.stl";
		string outputFile = "../data/test.binvox";*/

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
		//voxelizer.WriteSimple(outputFile);    //Enables to write a file in the vox format
//		voxelizer.write(outputFile);
		voxelizer.WriteForView(outputFile); //Enables to write a file in the binvox format
		timer.Stop();
		cout << "writing file "; timer.PrintTimeInS();
		cout << "-------------------------------------------" << endl;
	} else {
		cout << "grid_size num_threads STL_file output_file" << endl;
	}
}

