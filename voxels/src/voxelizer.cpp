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
    output.open (_pFile.substr(0, _pFile.length()-4)+"-VotingSlice.txt");

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
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-VotingSlice.txt" << endl;
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

void Voxelizer::writeVotingToTextFile(vector<vector<vector<int> > > const& votingTensor)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4) + "-votingTensor.txt");
    
    cout << votingTensor.size() << endl; 
    
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
vector<vector<vector<int> > > Voxelizer::voting()
{
    vector<vector<vector<int> > > accumulator(vector<vector<vector<int> > > (_size, vector<vector<int> >(_size, vector<int>(_size, 0))));
    for (int x(0); x < _size; x++)
    {
        for (int y(0); y < _size; y++)
        {
            for (int z(0); z < _size; z++)
            {
                size_t sum(0);
                if(_binaryTensor[x][y][z])
                {
                    for (int i(-1); i <= 1; i++) //3D Cube structuring element of size 3x3x3
                    {
                        for (int j(-1); j <= 1; j++)
                        {
                            for (int k(-1); k <= 1; k++)
                            {
                                if(!(x+i<0) && x+i < _size && !(y+j < 0) && (y+j < _size) && !(z+k<0) && z+k < _size) //Avoid segfault at the boudaries
                                {
                                    if(_binaryTensor[x+i][y+j][z+k])
                                    {
                                        sum++;
                                    }
                                }
                            }
                        }
                    }
                    if(sum != 27) //if one voxel of the structuring element is outside of the shape
                    {
                        for(size_t m(0); m < _size; m++)
                        {
                            accumulator[m][y][z]++; //we increment the whole colum x for fixed y and z
                            accumulator[x][m][z]++; //we increment the whole colum y for fixed x and z
                            accumulator[x][y][m]++; //we increment the whole colum z for fixed y and x
                        }
                    }
                }
            }
        }
    }
    return accumulator;
}

//Visualize a single slice in Excel (for instance)
void Voxelizer::writeSliceVotingTextFile(unsigned int const& sliceNumber, vector<vector<vector<int> > > const& tensor)
{
    ofstream output;
    output.open (_pFile.substr(0, _pFile.length()-4)+"-outfileVoting.txt");
    
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
    cout << "Model Slice saved to " << _pFile.substr(0, _pFile.length()-4) << "-outfileVoting.txt" << endl;
}

//  output is a binary image
//  1: not a min region
//  0: part of a min region
//  2: not sure if min or not
//  3: uninitialized
void Voxelizer::imregionalmin(cv::Mat& img, cv::Mat& out_img)
{
    // pad the border of img with 1 and copy to img_pad
    cv::Mat img_pad;
    cv::copyMakeBorder(img, img_pad, 1, 1, 1, 1, IPL_BORDER_CONSTANT, 1);

    //  initialize binary output to 2, unknown if min
    out_img = cv::Mat::ones(img.rows, img.cols, CV_8U)+2;

    //  initialize pointers to matrices
    float* in = (float *)(img_pad.data);
    uchar* out = (uchar *)(out_img.data);

    //  size of matrix
    int in_size = img_pad.cols*img_pad.rows;
    int out_size = img.cols*img.rows;

    int x, y;
    for (int i = 0; i < out_size; i++) {
        //  find x, y indexes
        y = i % img.cols;
        x = i / img.cols;

        neighborCheck(in, out, i, x, y, img_pad.cols);  //  all regions are either min or max
    }

    cv::Mat label;
    cv::connectedComponents(out_img, label);

    int* lab = (int *)(label.data);

    in = (float *)(img.data);
    in_size = img.cols*img.rows;

    std::vector<int> bad_labels;

    for (int i = 0; i < out_size; i++) {
        //  find x, y indexes
        y = i % img.cols;
        x = i / img.cols;

        if (lab[i] != 0) {
            if (neighborCleanup(in, out, i, x, y, img.rows, img.cols) == 1) {
                bad_labels.push_back(lab[i]);
            }
        }
    }

    std::sort(bad_labels.begin(), bad_labels.end());
    bad_labels.erase(std::unique(bad_labels.begin(), bad_labels.end()), bad_labels.end());

    for (int i = 0; i < out_size; ++i) {
        if (lab[i] != 0) {
            if (std::find(bad_labels.begin(), bad_labels.end(), lab[i]) != bad_labels.end()) {
                out[i] = 0;
            }
        }
    }
}

int inline Voxelizer::neighborCleanup(float* in, uchar* out, int i, int x, int y, int x_lim, int y_lim)
{
    int index;
    for (int xx = x - 1; xx < x + 2; ++xx) {
        for (int yy = y - 1; yy < y + 2; ++yy) {
            if (((xx == x) && (yy==y)) || xx < 0 || yy < 0 || xx >= x_lim || yy >= y_lim)
                continue;
            index = xx*y_lim + yy;
            if ((in[i] == in[index]) && (out[index] == 0))
                return 1;
        }
    }

    return 0;
}

void inline Voxelizer::neighborCheck(float* in, uchar* out, int i, int x, int y, int x_lim)
{
    int indexes[8], cur_index;
    indexes[0] = x*x_lim + y;
    indexes[1] = x*x_lim + y+1;
    indexes[2] = x*x_lim + y+2;
    indexes[3] = (x+1)*x_lim + y+2;
    indexes[4] = (x + 2)*x_lim + y+2;
    indexes[5] = (x + 2)*x_lim + y + 1;
    indexes[6] = (x + 2)*x_lim + y;
    indexes[7] = (x + 1)*x_lim + y;
    cur_index = (x + 1)*x_lim + y+1;

    for (int t = 0; t < 8; t++) {
        if (in[indexes[t]] < in[cur_index]) {
            out[i] = 0;
            break;
        }
    }

    if (out[i] == 3)
        out[i] = 1;
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
