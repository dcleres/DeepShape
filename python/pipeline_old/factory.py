# import packages
import numpy as np
import random
import functools
from itertools import product as all_combinations

# TO DO: factor out, optimize
def generate_cube(resolution):
    
    print('generating cube..')

    dx = 1/resolution
    x_ = np.arange(0,1 + dx,dx)
    y_ = np.arange(0,1 + dx,dx)
    z_ = np.arange(0,1 + dx,dx)

    # get vertices for 2D face to define traingulation
    verts = np.asarray([[x,y] for x in x_ for y in y_ ])
    # define connectivity once for all
    from scipy.spatial import Delaunay
    tri = Delaunay(verts)
    N = ((1/dx)+1)**2
    
    x = np.arange(0,1 + dx,dx)
    x = x.reshape((-1,1))
    x = x.repeat(x.shape[0],axis = 1)
    verts0 = np.concatenate(np.stack([x,np.transpose(x),0*x],axis = 2))
    verts1 = np.concatenate(np.stack([x,0*x,np.transpose(x)[:,::-1]],axis = 2))
    verts2 = np.concatenate(np.stack([x,np.transpose(x)[:,::-1],0*x + 1],axis = 2))
    verts3 = np.concatenate(np.stack([x,0*x + 1,np.transpose(x)],axis = 2))
    verts4 = np.concatenate(np.stack([0*x,np.transpose(x),x[::-1]],axis = 2))
    verts5 = np.concatenate(np.stack([0*x + 1,np.transpose(x),x],axis = 2))

    #Define cube structure
    # face 0
    #verts0 = np.asarray([[x,y,0] for x in x_ for y in y_ ])
    faces0 = np.flip(tri.simplices,axis = 1)
    # face 5
    #verts5 = np.asarray([[x,y,1] for x in x_ for y in y_ ])
    faces5 = np.flip(tri.simplices,axis = 1) + N
    # face 1
    #verts1 = np.asarray([[x,0,z] for x in x_ for z in z_ ])
    faces1 = np.flip(tri.simplices,axis = 1) + 2*N
    # face 3
    #verts3 = np.asarray([[x,1,z] for x in x_ for z in z_ ])
    faces3 = np.flip(tri.simplices,axis = 1) + 3*N
    # face 2
    #verts2 = np.asarray([[0,y,z] for y in y_ for z in z_ ])
    faces2 = np.flip(tri.simplices,axis = 1) + 4*N
    # face 4
    #verts4 = np.asarray([[1,y,z] for y in y_ for z in z_ ])
    faces4 = np.flip(tri.simplices,axis = 1) + 5*N

    verts =  np.concatenate([verts0,verts1,verts2,verts3,verts4,verts5])
    faces = np.concatenate([faces0,faces1,faces2,faces3,faces4,faces5])

    # find duplicates and fix connectivity
    _,indexes,inverse_map = np.unique(verts,return_index=True,return_inverse=True, axis =0)
    # keep initial ordering
    verts_unique = verts[np.sort(indexes),:]
    _,sort_map= np.unique(verts_unique,return_index=True, axis =0)

    # clean up
    for i in range(verts_unique.shape[0]):
        for j in range(verts.shape[0]):
            if ((verts_unique[i,0]==verts[j,0] and verts_unique[i,1]==verts[j,1] and verts_unique[i,2]==verts[j,2] )):
                faces[faces==j]=i
                

    return verts_unique,faces.astype(int),sort_map,inverse_map