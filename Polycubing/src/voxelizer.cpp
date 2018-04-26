/*
 * Voxelizer.cpp
 *
 *  Created on: 22 Jun, 2014
 *      Author: chenqian
 */

#include "voxelizer.h"
#include <exception>

//#include <stdio.h>
//#include <unistd.h>
//#include <cstring> /* For strcmp() */
//#include <cstdlib> /* For EXIT_FAILURE, EXIT_SUCCESS */
//#include <vector> /* For STL */
//#include "/Applications/MATLAB_R2018a.app/extern/include/mat.h"*/

#define BUFSIZE 256


Voxelizer::Voxelizer(int size, const string& pFile, bool verbose)
        :  _verbose(verbose), _size(size), _pFile(pFile)
{
	if (_verbose) cout << "voxelizer init... " << endl;
	_isInit = false;

    _binaryTensorFlood = vector<vector<vector<bool> > > (_size, vector<vector<bool> >(_size, vector<bool>(_size, false)));
    _binaryTensor = vector<vector<vector<bool> > > (_size, vector<vector<bool> >(_size, vector<bool>(_size, false)));

	const aiScene* scene;
	try {
		/*
		 * Load scene
		 * */
		Assimp::Importer importer;
		scene = importer.ReadFile(pFile, aiProcessPreset_TargetRealtime_Fast);
		if (!scene) {
			throw std::runtime_error("Scene fails to be loaded!");
		}
		aiMesh* mesh = scene->mMeshes[0];
		_size2 = _size*_size;
		_totalSize = size*size*size/BATCH_SIZE;

		/**
		 * Reset voxels.
		 */
		_voxels.reset(new auint[_totalSize], ArrayDeleter<auint>());
		_voxelsBuffer.reset(new auint[_totalSize], ArrayDeleter<auint>());
		memset(_voxels.get(), 0, _totalSize * sizeof(int));
 		memset(_voxelsBuffer.get(), 0, _totalSize * sizeof(int));

		/**
		 * Store info.
		 */
		_numVertices = mesh->mNumVertices;
		_numFaces = mesh->mNumFaces;
		if (_verbose) cout << "faces : " << _numFaces << std::endl;
		if (_verbose) cout << "vertices : " << _numVertices << std::endl;
		_LoadFromMesh(mesh);

		if (!scene) delete scene;
		_isInit = true;
	} catch (std::exception& e) {
		cout << e.what() << endl;
		if (!scene) delete scene;
	}
	if (_verbose) cout << "done." << endl;
}

/**
 * Given voxel (int x, int y, int z), return loc (float x, float y, float z)
 */
v3_p Voxelizer::GetLoc(const v3_p& voxel) {
	Vec3f tmp = *_lb + (*_bound) * (*voxel) / (float) _size;
	v3_p loc(new Vec3f(tmp));
	return loc;
}


v3_p Voxelizer::GetLoc(const Vec3f& voxel) {
	Vec3f tmp = *_lb + (*_bound) * (voxel) / (float) _size;
	v3_p loc(new Vec3f(tmp));
	return loc;
}

/**
 * Given loc (float x, float y, float z), return voxel (int x, int y, int z)
 */
v3_p Voxelizer::GetVoxel(const Vec3f& loc) {
	Vec3f tmp = (loc - (*_lb)) * (float) _size / (*_bound);
	v3_p voxel(new Vec3f((int)tmp[0], (int)tmp[1], (int)tmp[2]));
	return voxel;
}

/**
 * Given loc (float x, float y, float z), return voxel (int x, int y, int z)
 */
v3_p Voxelizer::GetVoxel(const v3_p& loc) {
	Vec3f tmp = ((*loc) - (*_lb)) * (float) _size / (*_bound);
	v3_p voxel(new Vec3f((int)tmp[0], (int)tmp[1], (int)tmp[2]));
	return voxel;
}



/**
 *Get the collision object form triangle(face) id;
 */
inline tri_p Voxelizer::_GetTri(const int triId) {
	const Vec3f& vIds = _faces.get()[triId];
	tri_p tri(new TriangleP(_vertices.get()[(int)vIds[0]], _vertices.get()[(int)vIds[1]], _vertices.get()[(int)vIds[2]]));
	return tri;
}

/**
 * Load info from mesh.
 */
inline void Voxelizer::_LoadFromMesh(const aiMesh* mesh) {
	_vertices.reset(new Vec3f[_numVertices], ArrayDeleter<Vec3f>());
	Vec3f tmp;
	for (size_t i = 0; i < _numVertices; ++i) {
		_vertices.get()[i] = Vec3f(mesh->mVertices[i].x, mesh->mVertices[i].y,
				mesh->mVertices[i].z);
		if (i == 0) {
			_meshLb.reset(new Vec3f(mesh->mVertices[i].x, mesh->mVertices[i].y,
							mesh->mVertices[i].z));
			_meshUb.reset(new Vec3f(mesh->mVertices[i].x, mesh->mVertices[i].y,
							mesh->mVertices[i].z));
		} else {
			_meshLb->ubound(_vertices.get()[i]); // bug1
			_meshUb->lbound(_vertices.get()[i]); // bug2
		}
	}

	_meshLb.reset(new Vec3f((*_meshLb)-Vec3f(0.0001, 0.0001, 0.0001)));
	_meshUb.reset(new Vec3f((*_meshUb)+Vec3f(0.0001, 0.0001, 0.0001)));


	/**
	*
	*/
	_minLb = (*_meshLb)[0];
	_minLb = min(_minLb, (float)(*_meshLb)[1]);
	_minLb = min(_minLb, (float)(*_meshLb)[2]);
	_maxUb = (*_meshUb)[0];
	_maxUb = max(_maxUb, (float)(*_meshUb)[1]);
	_maxUb = max(_maxUb, (float)(*_meshUb)[2]);
	_lb.reset(new Vec3f(_minLb, _minLb, _minLb));
	_ub.reset(new Vec3f(_maxUb, _maxUb, _maxUb));
	_bound.reset(new Vec3f((*_ub - *_lb)));

	_faces.reset(new Vec3f[_numFaces], ArrayDeleter<Vec3f>());
	for (size_t i = 0; i < _numFaces; ++i) {
		_faces.get()[i] = Vec3f(mesh->mFaces[i].mIndices[0],
				mesh->mFaces[i].mIndices[1], mesh->mFaces[i].mIndices[2]);
	}
	_RandomPermutation(_faces, _numFaces);

	Vec3f halfUnit = (*_bound) / ((float) _size*2);
	_halfUnit.reset(new Vec3f(halfUnit));
	_meshVoxLB = GetVoxel(_meshLb);
	_meshVoxUB = GetVoxel(_meshUb);

	if (_verbose) cout << "space : " << *_lb << ", " << *_ub << endl;
	if (_verbose) cout << "mesh bound : " << *_meshLb << ", " << *_meshUb << endl;
}


/**
 * voxelize the surface.
 */
void Voxelizer::VoxelizeSurface(const int numThread) {
	if (!_isInit) {
		return;
	}
	if (_verbose) cout << "surface voxelizing... " << endl;
	ThreadPool tp(numThread);
	for (int i = 0; i < _numFaces; ++i) {
	 tp.Run(boost::bind(&Voxelizer::_RunSurfaceTask, this, i));
	}
	tp.Stop();
	if (_verbose) cout << "done." << endl;
}

/**
 * Details of surface task.
 */
inline void Voxelizer::_RunSurfaceTask(const int triId) {
	tri_p tri = _GetTri(triId);
	tri->computeLocalAABB();
	const v3_p lb = GetVoxel(tri->aabb_local.min_);
	const v3_p ub = GetVoxel(tri->aabb_local.max_);
	int lx = (*lb)[0], ux = (*ub)[0], ly = (*lb)[1], uy = (*ub)[1], lz = (*lb)[2], uz = (*ub)[2];

	/**
	 * when the estimated voxels are too large, optimize with bfs.
	 */
	int count = 0;
	int esti = min(ux - lx, min(uy - ly, uz - lz));
	unsigned int voxelInt, tmp;
	if (esti < 100) {
		v3_p vxlBox(new Vec3f(0, 0, 0));
		for (int x = lx, y, z; x <= ux; ++x) {
			for (y = ly; y <= uy; ++y) {
				for (z = lz; z <= uz; ++z) {
					voxelInt = x*_size2 + y*_size + z;
					tmp = (_voxels.get())[voxelInt / BATCH_SIZE].load();
					if (GETBIT(tmp, voxelInt)) continue;
					vxlBox->setValue(x, y, z);
					if (Collide(_halfUnit, GetLoc(vxlBox), tri)) {
						(_voxels.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
						count++;
					}
				}
			}
		}
	} else {
		count = _BfsSurface(tri, lb, ub);
	}

}

inline int Voxelizer::_BfsSurface(const tri_p& tri, const v3_p& lb, const v3_p& ub) {
	queue<unsigned int> q;
	hash_set set;
	unsigned int start = _ConvVoxelToInt(GetVoxel(tri->a)), topVoxelInt, tmp, newVoxelInt;
	q.push(start);
	set.insert(start);
	v3_p topVoxel;
	int count = 0;
	while (!q.empty()) {
		count++;
		topVoxelInt = q.front();
		q.pop();
		tmp = (_voxels.get())[topVoxelInt/BATCH_SIZE].load();
		topVoxel = _ConvIntToVoxel(topVoxelInt);
		if (GETBIT(tmp, topVoxelInt) || Collide(_halfUnit, GetLoc(topVoxel), tri)) {
			if (!GETBIT(tmp, topVoxelInt)) {
				(_voxels.get())[topVoxelInt / BATCH_SIZE] |= (1<<(topVoxelInt % BATCH_SIZE));
			}
			for (int i = 0; i < 6; ++i) {
				Vec3f newVoxel = *topVoxel + D_6[i];
				if (!_InRange(newVoxel, lb, ub)) continue;
				newVoxelInt = _ConvVoxelToInt(newVoxel);
				if (set.find(newVoxelInt) == set.end()) {
					set.insert(newVoxelInt);
					q.push(newVoxelInt);
				}
			}
		}
	}
	return count;
}

void Voxelizer::VoxelizeSolid(int numThread) {
	if (!_isInit) {
		return;
	}
	if (_verbose) cout << "solid voxelizing... " << endl;
	if (_verbose) cout << "round 1..." << endl;
	_RunSolidTask(numThread);
	if (_verbose) cout << "round 2..." << endl;
	_RunSolidTask2(numThread);
	for (int i = 0; i < _totalSize; ++i) _voxels.get()[i] = _voxelsBuffer.get()[i]^(~0);
	if (_verbose) cout << "done." << endl;
}

inline void Voxelizer::_BfsSolid(const unsigned int startInt) {

	unsigned int voxelInt = startInt, tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
	if (GETBIT(tmp, voxelInt)) return;
	queue<unsigned int> q;
	q.push(voxelInt);
	v3_p topVoxel(new Vec3f(0, 0, 0));
	while (!q.empty()) {
		voxelInt = q.front();
		tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
		q.pop();
		topVoxel = _ConvIntToVoxel(voxelInt);
		if (!GETBIT(tmp, voxelInt)) {
			(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<<(voxelInt % BATCH_SIZE));
			for (int i = 0; i < 6; i++) {
				Vec3f newVoxel = *topVoxel + D_6[i];
				if (!_InRange(newVoxel, _meshVoxLB, _meshVoxUB)) continue;
				voxelInt = _ConvVoxelToInt(newVoxel);
				tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
				if(!GETBIT(tmp, voxelInt)) q.push(voxelInt);
			}
		}

	}
}

inline bool Voxelizer::_InRange(const Vec3f& vc, const v3_p& lb, const v3_p& ub) {
	return vc[0]>=(*lb)[0] && vc[0]<=(*ub)[0] && vc[1]>=(*lb)[1] && vc[1]<=(*ub)[1] && vc[2]>=(*lb)[2] && vc[2]<=(*ub)[2];
}

inline bool Voxelizer::_InRange(const int& x, const int& y, const int& z, const int& lx, const int& ly, const int& lz, const int& ux, const int& uy, const int& uz) {
	return x>=lx && x<=ux && y>=ly && y<=uy && z>=lz && z<=uz;
}


inline v3_p Voxelizer::_ConvIntToVoxel(const unsigned int& coord) {
	v3_p voxel(new Vec3f(coord/_size2, (coord/_size)%_size, coord%_size));
	return voxel;
}

inline unsigned int Voxelizer::_ConvVoxelToInt(const v3_p& voxel) {
	return (*voxel)[0]*_size2 + (*voxel)[1]*_size + (*voxel)[2];
}

inline unsigned int Voxelizer::_ConvVoxelToInt(const Vec3f& voxel) {
	return voxel[0]*_size2 + voxel[1]*_size + voxel[2];
}


inline void Voxelizer::_RandomPermutation(const v3_p& data, int num) {
	for (int i = 0, id; i < num; ++i) {
		id = Random(i, num-1);
		if (i != id) swap((data.get())[i], (data.get())[id]);
	}
}

inline void Voxelizer::_FillYZ(const int x) {
	int ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2];
	unsigned int voxelInt, tmp;
	for (int y = ly, z; y <= uy; ++y) {
		for (z = lz; z <= uz; ++z) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
		if (z == uz+1) continue;
		for (z = uz; z >= lz; --z) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
	}
}

inline void Voxelizer::_FillYZ2(const int x) {
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2], nx, ny;
	unsigned int voxelInt, tmp;
	for (int y = ly, z; y <= uy; ++y) {
		for (z = lz; z <= uz; ++z) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					nx = x+DI_4[i][0]; ny = y+DI_4[i][1];
					if (nx>=lx && nx<=ux && ny>=ly && ny<=uy) {
						voxelInt = nx*_size2 + ny*_size + z;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
		if (z == uz+1) continue;
		for (z = uz; z >= lz; --z) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					nx = x+DI_4[i][0]; ny = y+DI_4[i][1];
					if (nx>=lx && nx<=ux && ny>=ly && ny<=uy) {
						voxelInt = nx*_size2 + ny*_size + z;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
	}
}

inline void Voxelizer::_FillXZ(const int y) {
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2];
	unsigned int voxelInt, tmp;
	for (int z = lz, x; z <= uz; ++z) {
		for (x = lx; x <= ux; ++x) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
		if (x == ux+1) continue;
		for (x = ux; x >= lx; --x) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
	}
}

inline void Voxelizer::_FillXZ2(const int y) {
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2], ny, nz;
	unsigned int voxelInt, tmp;
	for (int z = lz, x; z <= uz; ++z) {
		for (x = lx; x <= ux; ++x) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					ny = y+DI_4[i][0]; nz = z+DI_4[i][1];
					if (nz>=lz && nz<=uz && ny>=ly && ny<=uy) {
						voxelInt = x*_size2 + ny*_size + nz;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
		if (x == ux+1) continue;
		for (x = ux; x >= lx; --x) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					ny = y+DI_4[i][0]; nz = z+DI_4[i][1];
					if (nz>=lz && nz<=uz && ny>=ly && ny<=uy) {
						voxelInt = x*_size2 + ny*_size + nz;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
	}
}

inline void Voxelizer::_FillXY(const int z) {
	int ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0];
	unsigned int voxelInt, tmp;
	for (int x = lx, y; x <= ux; ++x) {
		for (y = ly; y <= uy; ++y) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
		if (y == uy+1) continue;
		for (y = uy; y >= ly; --y) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				(_voxelsBuffer.get())[voxelInt / BATCH_SIZE] |= (1<< (voxelInt % BATCH_SIZE));
			}
		}
	}
}

inline void Voxelizer::_FillXY2(const int z) {
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2], nx, nz;
	unsigned int voxelInt, tmp;
	for (int x = lx, y; x <= ux; ++x) {
		for (y = ly; y <= uy; ++y) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					nx = x+DI_4[i][0]; nz = z+DI_4[i][1];
					if (nz>=lz && nz<=uz && nx>=lx && nx<=ux) {
						voxelInt = nx*_size2 + y*_size + nz;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
		if (y == uy+1) continue;
		for (y = uy; y >= ly; --y) {
			voxelInt = x*_size2 + y*_size + z;
			tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
			if (GETBIT(tmp, voxelInt)) break;
			else {
				for (int i = 0; i < 4; ++i) {
					nx = x+DI_4[i][0]; nz = z+DI_4[i][1];
					if (nz>=lz && nz<=uz && nx>=lx && nx<=ux) {
						voxelInt = nx*_size2 + y*_size + nz;
						tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load() | (_voxelsBuffer.get())[voxelInt/BATCH_SIZE].load();
						if (!GETBIT(tmp, voxelInt)) _BfsSolid(voxelInt);
					}
				}
			}
		}
	}
}

inline void Voxelizer::_RunSolidTask(size_t numThread) {
	ThreadPool tp(numThread);
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2];
	for (int x = lx; x <= ux; ++x) {
		tp.Run(boost::bind(&Voxelizer::_FillYZ, this, x));
	}
	for (int y = ly; y <= uy; ++y) {
		tp.Run(boost::bind(&Voxelizer::_FillXZ, this, y));
	}
	for (int z = lz; z <= uz; ++z) {
		tp.Run(boost::bind(&Voxelizer::_FillXY, this, z));
	}
	tp.Stop();
}


inline void Voxelizer::_RunSolidTask2(size_t numThread) {
	ThreadPool tp(numThread);
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2];
	for (int x = lx; x <= ux; ++x) {
		tp.Run(boost::bind(&Voxelizer::_FillYZ2, this, x));
	}
	for (int z = lz; z <= uz; ++z) {
		tp.Run(boost::bind(&Voxelizer::_FillXY2, this, z));
	}
	for (int y = ly; y <= uy; ++y) {
		tp.Run(boost::bind(&Voxelizer::_FillXZ2, this, y));
	}
	tp.Stop();
}


/**
 * Write to file, with simple compression
 */
void Voxelizer::Write(const string& pFile) {

	if (_verbose) cout << "writing voxels to file..." << endl;
	int lx = (*_meshVoxLB)[0], ux = (*_meshVoxUB)[0], ly = (*_meshVoxLB)[1], uy = (*_meshVoxUB)[1], lz = (*_meshVoxLB)[2], uz = (*_meshVoxUB)[2];

    ofstream* output = new ofstream(pFile.c_str(), ios::out | ios::binary); //Opens the output file

    // write header
	*output << _size;
	*output << (double) (*_lb)[0] << (double) (*_lb)[1] << (double) (*_lb)[2];;
	*output << (double) (*_halfUnit)[0] * 2;
	*output << lx << ly << lz << uz << uy << uz;

	if (_verbose) cout << "grid size : " << _size << endl;
	if (_verbose) cout << "lower bound : " << (*_lb)[0] << " " << (*_lb)[1] << " " << (*_lb)[2] << endl;
	if (_verbose) cout << "voxel size : " << (*_halfUnit)[0] * 2 << endl;
	if (_verbose) cout << "voxel bound : (" << lx << " " << ly << " " << lz << "), " << " (" << ux << " " << uy << " " << uz << ")" << endl;

	//
	// write data
	//
	/**
		 * Compression
		 */
	int x = lx, y = ly, z = lz, index, totalOnes = 0;
	byte value, count;
	while (x <= ux) {
		index = x*_size2 + y*_size + z;
		value = GETBIT(_voxels.get()[index/BATCH_SIZE],index) ;
		count = 0;
		while ((x <= ux) && (count < 255) && (value == GETBIT(_voxels.get()[index/BATCH_SIZE],index))) {
			z++;
			if (z > uz) {
				z = lz;
				y++;
				if (y > uy) {
					y = ly;
					x++;
				}
			}
			index = x*_size2 + y*_size + z;
			count++;
		}
		if (value)
			totalOnes += count;
		*output << value << count;
	}

	output->close();
	if (_verbose) cout << "wrote " << totalOnes << " voxels" << endl;
}

/**
 * Write to file, with simple compression
 */
void Voxelizer::WriteForView(const string& pFile) {

	if (_verbose) cout << "writing voxels to file..." << endl;

	v3_p vxlBox(new Vec3f(0, 0, 0));
	int lx = 0, ux = _size - 1, ly = 0, uy = _size - 1, lz = 0, uz = _size - 1;
	int bx = ux-lx+1, by = uy-ly+1, bz = uz-lz+1;
	int meshLx = (*_meshVoxLB)[0], meshLy = (*_meshVoxLB)[1], meshLz = (*_meshVoxLB)[2];
	int meshUx = (*_meshVoxUB)[0], meshUy = (*_meshVoxUB)[1], meshUz = (*_meshVoxUB)[2];

	ofstream* output = new ofstream(pFile.c_str(), ios::out | ios::binary);

	Vec3f& norm_translate = (*_lb);
	float norm_scale = (*_bound).norm();

	//
	// write header
	//
	*output << "#binvox 1" << endl;
	*output << "dim " << bx  << " " << by << " " << bz << endl;
	if (_verbose) cout << "dim : " << bx << " x " << by << " x " << bz << endl;
	*output << "translate " << -norm_translate[0] << " " << -norm_translate[2]
			<< " " << -norm_translate[1] << endl;
	*output << "scale " << norm_scale << endl;
	*output << "data" << endl;

	byte value;
	byte count;
	int index = 0;
	int bytes_written = 0;
	int total_ones = 0;

	/**
	 * Compression
	 */
	int x = lx, y = ly, z = lz;
	while (x <= ux) {
		index = x*_size2 + y*_size + z;
		value = _InRange(x, y, z, meshLx, meshLy, meshLz, meshUx, meshUy, meshUz) ? GETBIT(_voxels.get()[index/BATCH_SIZE],index) : 0;
		count = 0;
		while ((x <= ux) && (count < 255) && (value == (_InRange(x, y, z, meshLx, meshLy, meshLz, meshUx, meshUy, meshUz) ? GETBIT(_voxels.get()[index/BATCH_SIZE],index) : 0))) {
			z++;
			if (z > uz) {
				z = lz;
				y++;
				if (y > uy) {
					y = ly;
					x++;
				}
			}
			index = x*_size2 + y*_size + z;
			count++;
		}
		if (value)
			total_ones += count;
		*output << value << count;
		bytes_written += 2;
	}

	output->close();
	if (_verbose) cout << "wrote " << total_ones << " set voxels out of " << bx*by*bz << ", in "
			<< bytes_written << " bytes" << endl;
}

/**
 * Write to file, without (simple) compression
 */
void Voxelizer::WriteSimple(const string& pFile) {
	if (_verbose) cout << "writing voxels to file..." << endl;
	int lx = 0, ux = _size-1, ly = 0, uy = _size-1, lz = 0, uz = _size-1;
	int meshLx = (*_meshVoxLB)[0], meshLy = (*_meshVoxLB)[1], meshLz = (*_meshVoxLB)[2];
	int meshUx = (*_meshVoxUB)[0], meshUy = (*_meshVoxUB)[1], meshUz = (*_meshVoxUB)[2];
	ofstream* output = new ofstream(pFile.c_str(), ios::out | ios::binary);

	//
	// write header
	//
	*output << _size << endl;
	*output << (double) (*_lb)[0] << " " << (double) (*_lb)[1] << " " << (double) (*_lb)[2] << endl;
	*output << (double) (*_halfUnit)[0] * 2 << endl;

	if (_verbose) cout << "dim : " << _size << " x " << _size << " x " << _size << endl;
	if (_verbose) cout << "lower bound : " << (*_lb) << endl;
	if (_verbose) cout << "voxel size : " << (*_halfUnit)[0] * 2 << endl;

	//
	// write data
	//
	unsigned int voxelInt, tmp, count = 0;

	for (int x = lx; x <= ux; ++x) {
		for (int y = ly; y <= uy; ++y) {
			for (int z = lz; z <= uz; ++z) {
				if (!_InRange(x, y, z, meshLx, meshLy, meshLz, meshUx, meshUy, meshUz)) continue;
				voxelInt = x*_size2 + y*_size + z;
				tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
				if (GETBIT(tmp, voxelInt)) {
					*output << x << ' ' << y << ' ' << z << '\n';
//					if (count == 0) cout << x << " " << y << " " << z << endl;
					++count;
				}
			}
		}
	}
	output->close();
	if (_verbose) cout << "wrote " << count << " voxels" << endl;
}

void Voxelizer::buildBinaryTensor()
{
    if (_verbose) cout << "writing voxels to file..." << endl;
    int lx = 0, ux = _size-1, ly = 0, uy = _size-1, lz = 0, uz = _size-1;
    int meshLx = (*_meshVoxLB)[0], meshLy = (*_meshVoxLB)[1], meshLz = (*_meshVoxLB)[2];
    int meshUx = (*_meshVoxUB)[0], meshUy = (*_meshVoxUB)[1], meshUz = (*_meshVoxUB)[2];

    // Fill the vector
    unsigned int voxelInt, tmp, count = 0;

    for (int x = lx; x <= ux; ++x) {
        for (int y = ly; y <= uy; ++y) {
            for (int z = lz; z <= uz; ++z) {
                if (!_InRange(x, y, z, meshLx, meshLy, meshLz, meshUx, meshUy, meshUz)) continue;
                voxelInt = x*_size2 + y*_size + z;
                tmp = (_voxels.get())[voxelInt/BATCH_SIZE].load();
                if (GETBIT(tmp, voxelInt)) {
                    _binaryTensor[x][y][z] = true;
                    ++count;
                }
            }
        }
    }
    if (_verbose) cout << "created the binary tensor mapping the " << count << " voxels" << endl;
}

//Visualize a single slice in Excel (for instance)
void Voxelizer::writeSliceTextFile(unsigned int const& sliceNumber)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4)+"-Slice.txt");

    vector<vector<bool> > element = _binaryTensor[sliceNumber];

    for (auto column : element)
    {
        for (auto line : column)
        {
            output << line << "\t";
        }
        output << endl;
    }
    
    output.close();
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-Slice.txt" << endl;
}

//Visualize a single slice in Excel (for instance)
void Voxelizer::writeSliceTextFile(vector<vector<vector<bool> > > const& binaryTensor, unsigned int const& sliceNumber, string const& filename)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4)+"-Slice"+filename+".txt");
    
    vector<vector<bool> > element = binaryTensor[sliceNumber];
    
    for (auto column : element)
    {
        for (auto line : column)
        {
            output << line << "\t";
        }
        output << endl;
    }
    
    output.close();
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-Slice"+filename+".txt" << endl;
}


//Visualize a single slice in Excel (for instance)
void Voxelizer::writeSliceTextFileXProj(vector<vector<vector<int> > > const& votingTensor, unsigned int const& sliceNumber, string const& filename)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4)+"-Slice"+filename+"-Projection.txt");

    for (int i(0); i < votingTensor.size(); i++)
    {
        for (int j(0); j< votingTensor[i][sliceNumber].size(); j++)
        {
            output << votingTensor[i][sliceNumber][j] << "\t";
        }
        output << endl;
    }
    
    output.close();
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-Slice"+filename+".txt" << endl;
}

void Voxelizer::writeTextFile()
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4) + "-voxelized.txt");
    
    for(auto const& xslice : _binaryTensor)
    {
        for (auto const& column : xslice)
        {
            for (auto const& line : column)
            {
                output << line << "\t";
            }
        }
        output << endl; //one line per x axis slide of the grid
    }
    output.close();
    cout << "Model saved to " << _pFile.substr(0, _pFile.length()-4) << "-voxelized.txt" << endl;
}

void Voxelizer::writeTextFileXProj(unsigned int const& sliceNumber)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4) + "-XProj.txt");
    
    for (int i(0); i < _binaryTensor.size(); i++)
    {
        for (int j(0); j< _binaryTensor[i][sliceNumber].size(); j++)
        {
            output << _binaryTensor[i][sliceNumber][j] << "\t";
        }
        output << endl;
    }
    
    output.close();
    cout << "Model saved to " << _pFile.substr(0, _pFile.length()-4) << "-XProj.txt" << endl;
}

void Voxelizer::writeTextFile(vector<vector<vector<bool> > > const& binaryTensor, string filename)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4) + "-" + filename + "voxelized.txt");
    
    for(auto const& xslice : binaryTensor)
    {
        for (auto const& column : xslice)
        {
            for (auto const& line : column)
            {
                output << line << "\t";
            }
        }
        output << endl; //one line per x axis slide of the grid
    }
    output.close();
    cout << "Model saved to " << _pFile.substr(0, _pFile.length()-4) << "-" + filename
    + "voxelized.txt" << endl;
}


void Voxelizer::writeVotingToTextFile(vector<vector<vector<int> > > const& votingTensor)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4) + "-votingTensor.txt");
    
    for(auto const& xslice : votingTensor)
    {
        for (auto const& column : xslice)
        {
            for (auto const& line : column)
            {
                output << line << "\t";
            }
        }
        output << endl; //one line per x axis slide of the grid
    }
    output.close();
    cout << "Voting Tensor saved to " << _pFile.substr(0, _pFile.length()-4) << "-votingTensor.txt" << endl;
}

/*
 * Is used for edge detection for the polycube. We use a 3x3 square structuring element to
 * find the corner on the cube.
 */
vector<vector<vector<int> > > Voxelizer::voting(int const& maskSize, vector<vector<vector<bool> > > const& binaryTensor)
{
    vector<vector<vector<int> > > accumulator(vector<vector<vector<int> > > (_size, vector<vector<int> >(_size, vector<int>(_size, 0))));
    for (int x(0); x < _size; x++)
    {
        for (int y(0); y < _size; y++)
        {
            for (int z(0); z < _size; z++)
            {
                size_t sum(0);
                if(binaryTensor[x][y][z])
                {
                    for (int i(-1); i <= 1; i++) //3D Cube structuring element of size 3x3x3
                    {
                        for (int j(-1); j <= 1; j++)
                        {
                            for (int k(-1); k <= 1; k++)
                            {
                                if(!(x+i<0) && x+i < _size && !(y+j < 0) && (y+j < _size) && !(z+k<0) && z+k < _size) //Avoid segfault at the boudaries
                                {
                                    if(binaryTensor[x+i][y+j][z+k])
                                    {
                                        sum++;
                                    }
                                }
                            }
                        }
                    }
                    if(sum != 27) //if one voxel of the structuring element is outside of the shape
                    {
                        for(int m(-maskSize); m < maskSize; m++)
                        {
                            if (x+m<0||y+m<0||z+m<0||x+m>_size||y+m>_size||z+m>_size)
                                continue;
                            
                            accumulator[x+m][y][z]++; //we increment the whole colum x for fixed y and z
                            accumulator[x][y+m][z]++; //we increment the whole colum y for fixed x and z
                            accumulator[x][y][z+m]++; //we increment the whole colum z for fixed y and x
                        }
                    }
                }
            }
        }
    }
    return accumulator;
}

//Visualize a single slice in Excel (for instance)
void Voxelizer::writeSliceVotingTextFile(unsigned int const& sliceNumber, vector<vector<vector<int> > > const& tensor, string filename)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4)+"-outfile"+filename+".txt");
    
    vector<vector<int> > element = tensor[sliceNumber];
    
    for (auto column : element)
    {
        for (auto line : column)
        {
            output << line << "\t";
        }
        output << endl;
    }
    
    output.close();
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-outfile"+filename+".txt" << endl;
}

// Note the smaller regionSize is the better it is
vector<vector<vector<bool> > > Voxelizer::neighbourhoodCorrection(int regionSize, vector<vector<vector<int> > >& counterMatrix)
{
    vector<vector<vector<bool> > > localCorrection = _binaryTensor;
    for (int x(0); x < _size; x++)
    {
        for (int y(0); y < _size; y++)
        {
            for (int z(0); z < _size; z++)
            {
                int counter(0);
                for(int i(-1); i <= 1; i++)
                {
                    for(int j(-1); j <= 1; j++)
                    {
                        for(int k(-1); k <= 1; k++)
                        {
                            if (i==0 && j==0 && k==0)
                                continue;
                            if (!(x+i<0 || y+j<0 || z+k<0 || x+i>=_size || y+j>=_size || z+k>=_size ))
                            {
                                if (_binaryTensor[x+i][y+j][z+k])
                                {
                                    counter++;
                                }
                            }
                        }
                    }
                }
   
                if (counter > 9)
                {
                    counterMatrix[x][y][z] = counter;
                    localCorrection[x][y][z] = true;
                }
            }
        }
    }
    return localCorrection;
}

// Note the smaller regionSize is the better it is
 vector<vector<vector<bool> > > Voxelizer::findRegionalMaxima(int regionSize, vector<vector<vector<int> > > const& votingMatrix)
{
    vector<vector<vector<bool> > > localMaxima = vector<vector<vector<bool> > > (_size, vector<vector<bool> >(_size, vector<bool>(_size, false)));
    
    for (int x(1); x < _size - 1; x++)
    {
        for (int y(1); y < _size - 1; y++)
        {
            for (int z(1); z < _size - 1; z++)
            {
                int counter(0);
                if (_binaryTensor[x][y][z]) //means we are inside the figure
                {
                    for(int i(-1); i <= 1; i++)
                    {
                         for(int j(-1); j <= 1; j++)
                         {
                              for(int k(-1); k <= 1; k++)
                              {
                                  if (i==0 && j==0 && k==0)
                                      continue;
                                  
                                  if (_binaryTensor[x+i][y+j][z+k])
                                  {
                                      counter++;
                                  }
                              }
                         }
                    }
                    //cout << counter << endl;
                    if(counter <= 20) // Is on the boarder/corner?
                    {
                        //Now we need to look at the voting matrix to find which is the point in neighborhood inside the figure
                        int max(0);
                        int xmax(0);
                        int ymax(0);
                        int zmax(0);

                        for(int i(-regionSize); i <= regionSize; i++)
                        {
                            for(int j(-regionSize); j <= regionSize; j++)
                            {
                                for(int k(-regionSize); k <= regionSize; k++)
                                {
                                    if (not(i==0 && j==0 && k==0))
                                    {
                                        if (!(x+i<0||y+j<0||z+k<0||x+i>=_size||y+j>=_size||z+k>=_size))
                                        {
                                            //cout << votingMatrix[x+i][y+j][k+z] << endl;
                                            if(votingMatrix[x+i][y+j][k+z] > max)
                                            {
                                                max = votingMatrix[x+i][y+j][k+z];
                                                xmax = x+i;
                                                ymax = y+j;
                                                zmax = z+k;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        //The local maxima is assigned to be a "corner" of the picure
                        localMaxima[xmax][ymax][zmax] = true;
                    }
                }
            }
        }
    }
    return localMaxima;
}

void Voxelizer::openCV(vector<vector<vector<int> > > const& votingMatrix)
{
    cv::Mat src = cv::Mat::zeros(100,100, CV_64F);
    cv::Mat src_gray;
    
    for (int i(0); i < src.rows; i++)
    {
        for (int j(0); j < src.cols; j++)
        {
            src.at<double>(i,j) = votingMatrix[43][i][j];
        }
    }
    cv::imwrite("output.png", src);
    
    src = cv::imread("output.png");
    cvtColor( src, src_gray, cv::COLOR_BGR2GRAY );
    blur( src_gray, src_gray, cv::Size(3,3) );
    const char* source_window = "Source";
    namedWindow( source_window, cv::WINDOW_AUTOSIZE );
    imshow( source_window, src );
    imshow( source_window, src_gray );

    /*
    cv::Mat src;
    cv::Mat src_gray;
    int thresh = 100;
    cv::RNG rng(12345);
    void thresh_callback(int, void* );
    
    src = cv::imread("/Users/davidcleres/DeepShape/Polycubing/data/img.png", 1 );
    cvtColor( src, src_gray, cv::COLOR_BGR2GRAY );
    blur( src_gray, src_gray, cv::Size(3,3) );
    const char* source_window = "Source";
    namedWindow( source_window, cv::WINDOW_AUTOSIZE );
    imshow( source_window, src );*/
    
    /*  //HULL
    cv::Mat src_copy = src.clone();
    cv::Mat threshold_output;
    vector<vector<cv::Point> > contours;
    vector<cv::Vec4i> hierarchy;
    threshold( src_gray, threshold_output, thresh, 255, cv::THRESH_BINARY );
    findContours( threshold_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
    vector<vector<cv::Point> >hull( contours.size() );
    for( size_t i = 0; i < contours.size(); i++ )
    {   convexHull( cv::Mat(contours[i]), hull[i], false ); }
    cv::Mat drawing = cv::Mat::zeros( threshold_output.size(), CV_8UC3 );
    for( size_t i = 0; i< contours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        drawContours( drawing, contours, (int)i, color, 1, 8, vector<cv::Vec4i>(), 0, cv::Point() );
        drawContours( drawing, hull, (int)i, color, 1, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
    namedWindow( "Hull demo", cv::WINDOW_AUTOSIZE );
    imshow( "Hull demo", drawing );*/
    
    /*cv::Mat threshold_output;
    vector<vector<cv::Point> > contours;
    vector<cv::Vec4i> hierarchy;
    threshold( src_gray, threshold_output, thresh, 255, cv::THRESH_BINARY );
    findContours( threshold_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
    vector<vector<cv::Point> > contours_poly( contours.size() );
    vector<cv::Rect> boundRect( contours.size() );
    vector<cv::Point2f>center( contours.size() );
    vector<float>radius( contours.size() );
    for( size_t i = 0; i < contours.size(); i++ )
    { approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
        boundRect[i] = boundingRect( cv::Mat(contours_poly[i]) );
        minEnclosingCircle( contours_poly[i], center[i], radius[i] );
    }
    cv::Mat drawing = cv::Mat::zeros( threshold_output.size(), CV_8UC3);
    for( size_t i = 0; i< contours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        drawContours( drawing, contours_poly, (int)i, color, 1, 8, vector<cv::Vec4i>(), 0, cv::Point() );
        rectangle( drawing, boundRect[i].tl(), boundRect[i].br(), color, 2, 8, 0 );
        circle( drawing, center[i], (int)radius[i], color, 2, 8, 0 );
    }
    
    namedWindow( "Contours", cv::WINDOW_AUTOSIZE );
    imshow( "Contours", drawing );*/
    
    /*
    /// Global variables
    char* corners_window = "Corners detected";
    
    cv::Mat dst, dst_norm, dst_norm_scaled;
    dst = cv::Mat::zeros( src.size(), CV_32FC1 );
    
    /// Detector parameters
    int blockSize = 2;
    int apertureSize = 3;
    double k = 0.04;
    
    /// Detecting corners
    cornerHarris( src_gray, dst, blockSize, apertureSize, k, cv::BORDER_DEFAULT );
    
    /// Normalizing
    normalize( dst, dst_norm, 0, 255, cv::NORM_MINMAX, CV_32FC1, cv::Mat() );
    convertScaleAbs( dst_norm, dst_norm_scaled );
    
    /// Drawing a circle around corners
    for( int j = 0; j < dst_norm.rows ; j++ )
    { for( int i = 0; i < dst_norm.cols; i++ )
    {
        if( (int) dst_norm.at<float>(j,i) > thresh )
        {
            circle( dst_norm_scaled, cv::Point( i, j ), 5,  cv::Scalar(0), 2, 8, 0 );
        }
    }
    }
    /// Showing the result
    cv::namedWindow( corners_window, CV_WINDOW_AUTOSIZE );
    imshow( corners_window, dst_norm_scaled );*/
}

//Means along axes along each pair of axes find were the car is
//vector<Coord3D> Voxelizer::findBorders(vector<vector<vector<int> > > voting)
vector<vector<vector<bool> > > Voxelizer::findBorders(vector<vector<vector<int> > > voting)
{
    vector<double> meanX = vector<double>(_size, 0);
    vector<double> meanY = vector<double>(_size, 0);
    vector<double> meanZ = vector<double>(_size, 0);
    
    vector<double> Xs_init;
    vector<double> Xs_final;
    vector<double> Ys;
    Ys.clear();
    vector<double> Zs;
    Zs.clear();
    
    int idxBest(0);
    double maxSumMean(0);

    for (int y(0); y < _size; y++)
    {
        double sumX(0);
        double sumMean(0);
        
        for (int x(0); x < _size; x++)
        {
            for (int z(0); z < _size; z++)
            {
                if (_binaryTensor[x][y][z])
                {
                    sumX ++;
                }
            }
            sumMean+=sumX/_size; //supposition is that if the sum of the averages is the best one then we are in a nice slice of the object --> This is SLICE specific
            if(sumMean > maxSumMean)
            {
                maxSumMean = sumMean;
                sumMean = 0;
                idxBest = y;
            }
        }
    }
    
    cout << "the best frame is " << idxBest << endl;

    for (int z(0); z < _size; z++)
     {
         for (int x(0); x < _size; x++)
         {
             if(_binaryTensor[x][idxBest][z])
             {
                 Xs_init.push_back(x);
                 int itr(x);
                 while (_binaryTensor[itr][idxBest][z])
                 {
                     itr++;
                 }
                 Xs_final.push_back(itr-1);
                 break;
             }
         }
     }
    
    // using default comparison (operator <):
    std::sort (Xs_init.begin(), Xs_init.end());
    std::sort (Xs_final.begin(), Xs_final.end());
    
    int medianIdx(Xs_init.size()/2);
    int x_init(Xs_init[medianIdx]);
    int x_final(Xs_final[medianIdx]);
    

    cout << "x_init = " << Xs_init[medianIdx] << endl; //we take the median since it should represent the median ehavior of the object we study
    cout << "x_final= " << Xs_final[medianIdx] << endl;
    
    int middle (abs(Xs_final[medianIdx]+Xs_init[medianIdx])/2);
    cout << "middle is : " << middle << endl;
    
    for (int j(0); j < _size; j++)
    {
        double sumZ(0);
        double sumY(0);
        
        for (int k(0); k < _size; k++)
        {
            sumY += voting[middle][j][k];
            sumZ += voting[middle][k][j];
        }
        meanZ[j]=(sumZ/_size); //mean per columns
        cout << "meanZ " << j << " = " << meanZ[j] << endl;
        meanY[j]=(sumY/_size); //mean per lines
    }
    
    for (int j(0); j < 8; j++)
    {
        double maxZ(0);
        double maxY(0);
        int maxIdxZ(0);
        int maxIdxY(0);
        
        for (int o(0); o < _size; o++)
        {
            if(meanY[o] > maxY)
            {
                maxY = meanY[o];
                maxIdxY = o;
            }
            if(meanZ[o] > maxZ)
            {
                maxZ = meanZ[o];
                maxIdxZ = o;
            }
        }
        cout << "Pushed " << maxIdxZ << endl; 
        Zs.push_back(maxIdxZ);
        Ys.push_back(maxIdxY);
        
        meanZ[maxIdxZ] = 0; //Deletes the maxima values
        meanY[maxIdxY] = 0;
    }
    
    vector<vector<vector<bool> > >  output = vector<vector<vector<bool> > > (_size, vector<vector<bool> >(_size, vector<bool>(_size, false)));
    
    output[x_init][Ys[0]][Zs[0]] = true;
    output[x_init][Ys[0]][Zs[1]] = true;
    output[x_init][Ys[0]][Zs[2]] = true;
    output[x_init][Ys[0]][Zs[3]] = true;
    output[x_init][Ys[0]][Zs[4]] = true;
    output[x_init][Ys[0]][Zs[5]] = true;
    output[x_init][Ys[0]][Zs[6]] = true;
    output[x_init][Ys[0]][Zs[7]] = true;
    output[x_init][Ys[1]][Zs[0]] = true;
    output[x_init][Ys[1]][Zs[1]] = true;
    output[x_init][Ys[1]][Zs[2]] = true;
    output[x_init][Ys[1]][Zs[3]] = true;
    output[x_init][Ys[1]][Zs[4]] = true;
    output[x_init][Ys[1]][Zs[5]] = true;
    output[x_init][Ys[1]][Zs[6]] = true;
    output[x_init][Ys[1]][Zs[7]] = true;
    output[x_init][Ys[2]][Zs[0]] = true;
    output[x_init][Ys[2]][Zs[1]] = true;
    output[x_init][Ys[2]][Zs[2]] = true;
    output[x_init][Ys[2]][Zs[3]] = true;
    output[x_init][Ys[2]][Zs[4]] = true;
    output[x_init][Ys[2]][Zs[5]] = true;
    output[x_init][Ys[2]][Zs[6]] = true;
    output[x_init][Ys[2]][Zs[7]] = true;
    
    output[x_final][Ys[0]][Zs[0]] = true;
    output[x_final][Ys[0]][Zs[1]] = true;
    output[x_final][Ys[0]][Zs[2]] = true;
    output[x_final][Ys[0]][Zs[3]] = true;
    output[x_final][Ys[0]][Zs[4]] = true;
    output[x_final][Ys[0]][Zs[5]] = true;
    output[x_final][Ys[0]][Zs[6]] = true;
    output[x_final][Ys[0]][Zs[7]] = true;
    output[x_final][Ys[1]][Zs[0]] = true;
    output[x_final][Ys[1]][Zs[1]] = true;
    output[x_final][Ys[1]][Zs[2]] = true;
    output[x_final][Ys[1]][Zs[3]] = true;
    output[x_final][Ys[1]][Zs[4]] = true;
    output[x_final][Ys[1]][Zs[5]] = true;
    output[x_final][Ys[1]][Zs[6]] = true;
    output[x_final][Ys[1]][Zs[7]] = true;
    output[x_final][Ys[2]][Zs[0]] = true;
    output[x_final][Ys[2]][Zs[1]] = true;
    output[x_final][Ys[2]][Zs[2]] = true;
    output[x_final][Ys[2]][Zs[3]] = true;
    output[x_final][Ys[2]][Zs[4]] = true;
    output[x_final][Ys[2]][Zs[5]] = true;
    output[x_final][Ys[2]][Zs[6]] = true;
    output[x_final][Ys[2]][Zs[7]] = true;
    
    return output;
}

vector<vector<vector<bool> > > Voxelizer::buildPerfectPolyCube(vector<vector<vector<bool> > > edges)
{
    vector<vector<vector<bool> > >  output = vector<vector<vector<bool> > > (_size, vector<vector<bool> >(_size, vector<bool>(_size, false)));
    
    for(int i(0); i < _size; i++)
    {
        for(int j(0); j < _size; j++)
        {
            for(int k(0); k < _size; k++)
            {
                bool found(true);
                if(edges[i][j][k])
                {
                    //we found one corner and now we shoot out a new vector to find the next corner
                    int itrI(i+1);
                    while (itrI < _size && not(edges[itrI][j][k]))
                    {
                        if (itrI == _size-1)
                            found = false;
                        itrI++;
                    }

                    int itrJ(j+1);
                    while (itrJ < _size && not(edges[i][itrJ][k]))
                    {
                        if (itrJ == _size-1)
                            found = false;
                        itrJ++;
                    }

                    int itrK(k+1);
                    while (itrK < _size && not(edges[i][j][itrK]))
                    {
                        if (itrK == _size-1)
                            found = false;
                        itrK++;
                    }
                    
                    //Takes an area aroud the barycenter
                    for(int q(-1); q <= 1; q++)
                    {
                        for(int w(-1); w <= 1; w++)
                        {
                            for(int e(-1); e <= 1; e++)
                            {
                                //see if the barycenter is in the figure
                                int baryX((itrI+i+q)/2);
                                int baryY((itrJ+j+w)/2);
                                int baryZ((itrK+k+e)/2);
                                
                                if(_binaryTensor[baryX][baryY][baryZ] || found) // UNCOMMENT ME IF YOU ARE USING THE SET OF 1500 CARS !!!!!!!!!!
                                //if(_binaryTensor[baryX][baryY][baryZ])
                                {
                                    //this means that we are in the original figure and that we can fill a cube with ones
                                    for(int x(i); x < itrI; x++)
                                    {
                                        for(int y(j); y < itrJ; y++)
                                        {
                                            for(int z(k); z < itrK; z++)
                                            {
                                                output[x][y][z] = true;
                                            }
                                        }
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return output;
}

Voxelizer::~Voxelizer() {
	// TODO Auto-generated destructor stub
}

v3_p Voxelizer::GetVertices() {
	return _vertices;
}

v3_p Voxelizer::GetFaces() {
	return _faces;
}

int Voxelizer::GetVerticesSize() {
	return _numVertices;
}

int Voxelizer::GetFacesSize() {
	return _numFaces;
}

v3_p Voxelizer::GetLowerBound() {
	return _lb;
}

v3_p Voxelizer::GetUpperBound() {
	return _ub;
}

v3_p Voxelizer::GetMeshLowerBound() {
	return _meshLb;
}

v3_p Voxelizer::GetMeshUpperBound() {
	return _meshUb;
}

auint_p Voxelizer::GetVoxels() {
	return _voxels;
}

v3_p Voxelizer::GetHalfUnit() {
	return _halfUnit;
}

int Voxelizer::GetTotalSize() {
	return _totalSize;
}

vector<vector<vector<bool> > > Voxelizer::getBinarytensor()
{
    return _binaryTensor;
}
