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


# utils for mesh processing and visualization
def ssc(v):
    return np.matrix([[0.0,-v[2],v[1]],[v[2],0.0,-v[0]],[-v[1],v[0],0.0]])
    
def get_rotation_matrix(u,v):
    inner = np.inner(u,v)
    if inner > 0.999:
        return np.eye(3)
    if inner < -0.999:
        return -np.eye(3)
    else:
        M = ssc(np.cross(u,v))
        return np.eye(3) + M + np.matmul(M,M)*(1/(1+inner))

    
# LAPLACIAN SMOOTHING
    
def smooth_vector_field(mesh,field,n_iter = 1, lambda_ = -0.2):
    
    #TODO: consider different weights based on SOD score? we need to see that
    
    # assemble lhs
    lhs = field.reshape(-1,)
    x_ = lhs[0::3]
    y_ = lhs[1::3]
    z_ = lhs[2::3]
    
    
    # assemble laplacian matrix
    rhs = np.eye(mesh.nverts)
    for e0 in range(mesh.nverts):
        N = len(mesh.adjacency[e0])
        for e1 in mesh.adjacency[e0]:
            rhs[e0,e1] = -1.0/N
    
    # average out field
    for i in range(n_iter):
                
        x_ += lambda_*np.dot(rhs,x_)  
        y_ += lambda_*np.dot(rhs,y_)
        z_ += lambda_*np.dot(rhs,z_)
            
    return np.column_stack((x_,y_,z_))    


# ITERATIVE CLOSEST POINT

def compute_vertex_matching(p,q):
    dist = cdist(p, q)
    ind = np.argmin(dist, axis = 1)
    return q[ind.tolist(),:]

def rototrasl_allignment(mesh, mesh_target):
        
        q = compute_vertex_matching(mesh.vertices,mesh_target.vertices)
        #q = mesh.closest_point_projection(mesh_target.vertices)
        
        # set up linear system
        rhs = np.zeros((3*q.shape[0],6))
        lhs = -(mesh.vertices.reshape(-1,1)-q.reshape(-1,1))
        
        # TO DO: code it better
        for j in range(q.shape[0]):
            rhs[3*j,1] = mesh.vertices[j,2]
            rhs[3*j,2] = -mesh.vertices[j,1]
            rhs[3*j,3] = 1.0
            rhs[3*j+1,0] = -mesh.vertices[j,2]
            rhs[3*j+1,2] = mesh.vertices[j,0]
            rhs[3*j+1,4] = 1.0
            rhs[3*j+2,0] = mesh.vertices[j,1]
            rhs[3*j+2,1] = -mesh.vertices[j,0]
            rhs[3*j+2,5] = 1.0
        
        # solve linear system
        x = np.linalg.lstsq(rhs,lhs)[0]
        # compute rotation and translation
        R = np.ones((3,3))
        R[0,1]= -x[2]
        R[1,0]= x[2]
        R[0,2]= x[1]
        R[2,0]= -x[1]
        R[1,2]= -x[0]
        R[2,1]= x[0]
        t = np.squeeze(x[3:])
        mesh.apply_rototranslation(R,t)
        
        
def scale_allignment(mesh, mesh_target):
        
        q = compute_vertex_matching(mesh.vertices,mesh_target.vertices)
        #q = mesh.closest_point_projection(mesh_target.vertices)
        
        
        # set up linear system
        rhs = np.zeros((3*q.shape[0],6))
        lhs = -(mesh.vertices.reshape(-1,1)-q.reshape(-1,1))
        
        # TO DO: code it better
        for j in range(q.shape[0]):
            rhs[3*j,0] = mesh.vertices[j,0]
            rhs[3*j,3] = 1.0
            rhs[3*j+1,1] = mesh.vertices[j,1]
            rhs[3*j+1,4] = 1.0
            rhs[3*j+2,2] = mesh.vertices[j,2]
            rhs[3*j+2,5] = 1.0
        
        #print(rhs)
        # solve linear system
        x = np.linalg.lstsq(rhs,lhs)[0]
        # compute rotation and translation
        S = np.eye(3)
        S[0,0]= 1+x[0]
        S[1,1]= 1+x[1]
        S[2,2]= 1+x[2]
        t = np.squeeze(x[3:])
        mesh.apply_scalingtranslation(S,t)
    
    
    
    
#########################    
# PLOTTING UTILITIES    
##########################

def map_z2color(zval, colormap, vmin, vmax):
    #map the normalized value zval to a corresponding color in the colormap
    
    if vmin>vmax:
        raise ValueError('incorrect relation between vmin and vmax')
    t=(zval-vmin)/float((vmax-vmin))#normalize val
    R, G, B, alpha=colormap(t)
    return 'rgb('+'{:d}'.format(int(R*255+0.5))+','+'{:d}'.format(int(G*255+0.5))+\
           ','+'{:d}'.format(int(B*255+0.5))+')'   
    
def map_field2color(field, colormap, vmin, vmax):
    #map the normalized value zval to a corresponding color in the colormap   

    t=(field-vmin)/float((vmax-vmin))#normalize val
    R, G, B, alpha=colormap(t)
    return 'rgb('+'{:d}'.format(int(R*255+0.5))+','+'{:d}'.format(int(G*255+0.5))+\
           ','+'{:d}'.format(int(B*255+0.5))+')'   
    
def tri_indices(simplices):
    #simplices is a numpy array defining the simplices of the triangularization
    #returns the lists of indices i, j, k
    return ([triplet[c] for triplet in simplices] for c in range(3))


def display_meshes(meshes):
    
    data_figure = []
    for mesh in meshes:
        
        #x, y, z are lists of coordinates of the triangle vertices 
        #faces are the simplices that define the triangularization
        # normals are vertex normals
        x,y,z = zip(*mesh.vertices)
        simplices = mesh.faces
        normals = mesh.normals
        
        points3D=np.vstack((x,y,z)).T
        # map defining vertices of the surface triangles
        tri_vertices=map(lambda index: points3D[index], simplices)
        
        # mean values of z-coordinates of triangle vertices                                      
        zmean=[np.mean(tri[:,2]) for tri in tri_vertices ]
        min_zmean=np.min(zmean)
        max_zmean=np.max(zmean)  
        # use it for color mapping
        #colormap=cm.RdBu
        #facecolor=[map_z2color(zz,  colormap, min_zmean, max_zmean) for zz in zmean] 
        
        # get indices of triangles
        I,J,K=tri_indices(simplices)

        mesh_triangles=go.Mesh3d(x=x,
                         y=y,
                         z=z,
                         #facecolor=facecolor, 
                         i=I,
                         j=J,
                         k=K,
                         name=''
                        )
        data_figure.append(mesh_triangles)
        
    data =  go.Data(data_figure)
    layout = go.Layout(
            scene=dict(aspectmode="data")
        )
    fig = go.Figure(data=data, layout=layout)
    
    return iplot(fig)





