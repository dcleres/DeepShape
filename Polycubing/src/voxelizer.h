/*
 * Voxelizer.h
 *
 *  Created on: 22 Jun, 2014
 *      Author for the  pure Voxelization part: chenqian
 */

#ifndef VOXELIZER_H_
#define VOXELIZER_H_

#include <boost/shared_ptr.hpp>
#include <boost/atomic.hpp>
#include <assimp/Importer.hpp>      // C++ importer interface
#include <assimp/scene.h>           // Output data structure
#include <assimp/postprocess.h>     // Post processing flags
#include "commons.h"
#include "threadPool.h"
#include "timer.h"
#include <queue>
#include <fstream>

#include "opencv2/core.hpp"
#include "opencv2/face.hpp"
#include "opencv2/highgui.hpp"
#include "opencv2/imgproc.hpp"
#include "opencv2/objdetect.hpp"

#include "opencv2/imgcodecs.hpp"
#include <iostream>
#include <stdio.h>
#include <stdlib.h>

using namespace std;

const int BATCH_SIZE = 32;

#define GETBIT(x,i) ((x>>(i%BATCH_SIZE))&1)

struct Coord3D
{
    int x;
    int y;
    int z;
};

template<typename T>
struct ArrayDeleter {
	void operator ()(T const * p) {
		delete[] p;
	}
};

class Voxelizer {

    bool _isInit;
	bool _verbose;

	v3_p _meshLb, _meshUb; // location
	v3_p _meshVoxLB, _meshVoxUB; // voxels of location

	float _minLb, _maxUb;
	v3_p _lb, _ub, _bound; // lowerBound and upperBound of the whole space
	v3_p _halfUnit; // half size of the unit

	v3_p _faces;
	int _numFaces;

	v3_p _vertices;
	int _numVertices;

	auint_p _voxelsBuffer;
	auint_p _voxels;

	unsigned int _size, _totalSize, _size2; // size_2 = size*size & size = gridsize
	vector<vector<vector<bool> > > _binaryTensorFlood;
	vector<vector<vector<bool> > > _binaryTensor;
    string _pFile;

	inline void _LoadFromMesh(const aiMesh* mesh);
	inline void _RunSolidTask(size_t numThread=1);
	inline void _RunSolidTask2(size_t numThread=1);
	inline void _RunSurfaceTask(const int triId);
	inline void _FillYZ(const int x);
	inline void _FillXZ(const int y);
	inline void _FillXY(const int z);
	inline void _FillYZ2(const int x);
	inline void _FillXZ2(const int y);
	inline void _FillXY2(const int z);
	inline bool _InRange(const Vec3f& vc, const v3_p& lb, const v3_p& ub);
	inline bool _InRange(const int& x, const int& y, const int& z, const int& lx, const int& ly, const int& lz, const int& ux, const int& uy, const int& uz);

	inline tri_p _GetTri(const int triId);
	inline v3_p _ConvIntToVoxel(const unsigned int& coord);
	inline unsigned int _ConvVoxelToInt(const v3_p& voxel);
	inline unsigned int _ConvVoxelToInt(const Vec3f& voxel);
	inline int _BfsSurface(const tri_p& tri, const v3_p& lb, const v3_p& ub);
	inline void _RandomPermutation(const v3_p& data, int num);
	inline void _BfsSolid(const unsigned int voxelId);

public:
	int GetTotalSize();
	v3_p GetHalfUnit();
	auint_p GetVoxels();
	v3_p GetVoxel(const Vec3f& loc);
	v3_p GetVoxel(const v3_p& loc);
	v3_p GetLoc(const v3_p& voxel);
	v3_p GetLoc(const Vec3f& voxel);
	v3_p GetMeshLowerBound();
	v3_p GetMeshUpperBound();
	v3_p GetLowerBound();
	v3_p GetUpperBound();
	int GetVerticesSize();
	int GetFacesSize();
	v3_p GetVertices();
	v3_p GetFaces();
	void VoxelizeSurface(int numThread=1);
	void VoxelizeSolid(int numThread=1);
	void Write(const string& pFile);
	void WriteSimple(const string& pFile);
	void WriteForView(const string& pFile);
    void buildBinaryTensor();
    Voxelizer(int size, const string& pFile, bool verbose);
	void writeSliceTextFile(unsigned int const& sliceNumber);
    void writeSliceTextFile(vector<vector<vector<bool> > > const& binaryTensor, unsigned int const& sliceNumber);
    void writeTextFile();
    void writeTextFile(vector<vector<vector<bool> > > const& binaryTensor);
    void writeVotingToTextFile(vector<vector<vector<int> > > const& votingTensor);
    void writeSliceVotingTextFile(unsigned int const& sliceNumber, vector<vector<vector<int> > > const& tensor);

    vector<vector<vector<int> > > voting(int const& maskSize);
   
    void findCorners(vector<vector<vector<int> > > const& votingVector, unsigned int const& regionSize);
    
    vector<vector<vector<bool> > > findRegionalMaxima(int regionSize, vector<vector<vector<int> > > const& votingMatrix);
    
    /*vector<Coord3D> findBorders(vector<vector<vector<bool> > > regionalMax, vector<Coord3D> coordinatesToRemember);*/
    
    void openCV();
    virtual ~Voxelizer();
};

#endif /* VOXELIZER_H_ */
