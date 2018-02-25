# import packages
import numpy as np
import random
import functools
from itertools import product as all_combinations
import plotly 
import plotly.plotly as py
import plotly.graph_objs as go
import plotly.figure_factory as FF
import matplotlib.cm as cm
from plotly.offline import download_plotlyjs, init_notebook_mode, plot, iplot
import scipy.cluster.vq as cluster
from scipy.spatial.distance import cdist

# method for mapping field to color space
def map_field2color(field, colormap, vmin, vmax):
    #map the normalized value zval to a corresponding color in the colormap   

    t=(field-vmin)/float((vmax-vmin))#normalize val
    R, G, B, alpha=colormap(t)
    return 'rgb('+'{:d}'.format(int(R*255+0.5))+','+'{:d}'.format(int(G*255+0.5))+\
           ','+'{:d}'.format(int(B*255+0.5))+')' 
    
def map_z2color(zval, colormap, vmin, vmax):
    #map the normalized value zval to a corresponding color in the colormap
    
    if vmin>vmax:
        raise ValueError('incorrect relation between vmin and vmax')
    t=(zval-vmin)/float((vmax-vmin))#normalize val
    R, G, B, alpha=colormap(t)
    return 'rgb('+'{:d}'.format(int(R*255+0.5))+','+'{:d}'.format(int(G*255+0.5))+\
           ','+'{:d}'.format(int(B*255+0.5))+')'   
    
def tri_indices(simplices):
    #simplices is a numpy array defining the simplices of the triangularization
    #returns the lists of indices i, j, k
    return ([triplet[c] for triplet in simplices] for c in range(3))
    
# hard coded resolution parameter 
RESOLUTION = 25    

#######################################################    
# Main mesh class    
#######################################################

class Mesh:
    def __init__(self, filename = None):
        
        # create cube
        dx = 1/RESOLUTION
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
        faces0 = np.flip(tri.simplices,axis = 1)
        faces5 = np.flip(tri.simplices,axis = 1) + N
        faces1 = np.flip(tri.simplices,axis = 1) + 2*N
        faces3 = np.flip(tri.simplices,axis = 1) + 3*N
        faces2 = np.flip(tri.simplices,axis = 1) + 4*N
        faces4 = np.flip(tri.simplices,axis = 1) + 5*N

        verts =  np.concatenate([verts0,verts1,verts2,verts3,verts4,verts5])
        faces = np.concatenate([faces0,faces1,faces2,faces3,faces4,faces5])

        # find duplicates and fix connectivity
        _,indexes,inverse_map = np.unique(verts,return_index=True,return_inverse=True, axis =0)
        # keep initial ordering
        verts_unique = verts[np.sort(indexes),:]
        _,sort_map= np.unique(verts_unique,return_index=True, axis =0)

        # clean up face data structure
        for i in range(verts_unique.shape[0]):
            for j in range(verts.shape[0]):
                if ((verts_unique[i,0]==verts[j,0] and verts_unique[i,1]==verts[j,1] and verts_unique[i,2]==verts[j,2])):
                    faces[faces==j]=i
        
        # use deformed vertices
        verts_deformed =  np.concatenate(np.concatenate(np.load(filename)))
        verts_unique = verts_deformed[np.sort(indexes),:]
        # finalize loading
        self.vertices = verts_unique
        self.faces = faces.astype(int)
        self.nverts, self.nfaces =  self.vertices.shape[0],self.faces.shape[0]
        
        v = [self.vertices[self.faces[:, i], :] for i in range(3)]
        face_normals = np.cross(v[2] - v[0], v[1] - v[0])
        face_normals /= np.linalg.norm(face_normals, axis=1)[:, None]
        self.face_normals = face_normals
        
        self.normals = np.zeros((self.nverts, 3))
        # mean of sorrounding face normals
        for i, j in np.ndindex(self.faces.shape):
            self.normals[self.faces[i, j], :] += self.face_normals[i, :]
        self.normals /= np.linalg.norm(self.normals, axis=1)[:, None]
        
        self.adjacency = [set() for _ in range(self.nfaces)]
        for i, j in np.ndindex(self.faces.shape):
            e0, e1 = self.faces[i, j], self.faces[i, (j+1)%3]
            self.adjacency[e0].add(e1)
            self.adjacency[e1].add(e0)
        
    def visualize(self,colormap=cm.jet, plot_field=None, field=None):
        
        #x, y, z are lists of coordinates of the triangle vertices 
        #faces are the simplices that define the triangularization
        # normals are vertex normals

        x,y,z = zip(*self.vertices)
        simplices = self.faces
        normals = self.normals
        
        points3D=np.vstack((x,y,z)).T
        
        
        # map defining vertices of the surface triangles
        tri_vertices=map(lambda index: points3D[index], simplices)
        

        # use it for color mapping
        if plot_field is None:
             # mean values of z-coordinates of triangle vertices                                      
            zmean=[np.mean(tri[:,2]) for tri in tri_vertices ]
            min_zmean=np.min(zmean)
            max_zmean=np.max(zmean)  
            facecolor=[map_z2color(zz,  colormap, min_zmean, max_zmean) for zz in zmean] 
        elif plot_field is True:
            # field mean
            fmean= [1/3*(field[simplex[0]]+field[simplex[1]]+field[simplex[2]]) for simplex in simplices ]
            min_f=np.min(fmean)
            max_f=np.max(fmean)  
            facecolor=[map_field2color(f,  colormap, min_f, max_f) for f in fmean]
        
        # get indices of triangles
        I,J,K=tri_indices(simplices)

        triangles=go.Mesh3d(x=x,
                         y=y,
                         z=z,
                         facecolor=facecolor, 
                         i=I,
                         j=J,
                         k=K,
                         name=''
                        )
        
        layout = go.Layout(
            scene=dict(aspectmode="data")
        )


        data =  go.Data([triangles])
        fig = go.Figure(data=data, layout=layout)
        iplot(fig)
        
