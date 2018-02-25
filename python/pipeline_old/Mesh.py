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

import utils 
import factory


        
#######################################################    
# Main mesh class    
#######################################################

class Mesh:
    def __init__(self, filename = None, shape_factory = None, shape_resolution = -1, trig_loader = None, trig = None ):
        
        if trig_loader is True:
            self.vertices = trig.coords
            self.faces = trig.facets
            self.nverts, self.nfaces = self.vertices.shape[0],self.faces.shape[0]
        
        elif shape_factory is 'cube':
            self.shape_resolution = int(shape_resolution)
            self.vertices, self.faces,self.sort_map,self.inverse_map = factory.generate_cube(shape_resolution)
            self.nverts, self.nfaces = self.vertices.shape[0],self.faces.shape[0]
            
        else:
            # STANDARD LOADER FROM FILE
            print('Loading \"%s\" ..' % filename)
            with open(filename) as f:
                if f.readline().strip() != 'OFF': raise Exception("Invalid format")
                self.nverts, self.nfaces, _ = map(int, f.readline().split())
                self.vertices, self.faces = np.zeros((self.nverts, 3)), np.zeros((self.nfaces, 3), np.uint32)
                for i in range(self.nverts):
                    self.vertices[i, :] = np.fromstring(f.readline(), sep=' ')
                for i in range(self.nfaces):
                    self.faces[i, :] = np.fromstring(f.readline(), sep=' ', dtype=np.uint32)[1:]
                
        
        print('Computing face and vertex normals ..')
        v = [self.vertices[self.faces[:, i], :] for i in range(3)]
        face_normals = np.cross(v[2] - v[0], v[1] - v[0])
        face_normals /= np.linalg.norm(face_normals, axis=1)[:, None]
        self.face_normals = face_normals
        
        self.normals = np.zeros((self.nverts, 3))
        # mean of sorrounding face normals
        for i, j in np.ndindex(self.faces.shape):
            self.normals[self.faces[i, j], :] += self.face_normals[i, :]
        self.normals /= np.linalg.norm(self.normals, axis=1)[:, None]
        
        
        
        print('Building adjacency list ..')
        self.adjacency = [set() for _ in range(self.nfaces)]
        for i, j in np.ndindex(self.faces.shape):
            e0, e1 = self.faces[i, j], self.faces[i, (j+1)%3]
            self.adjacency[e0].add(e1)
            self.adjacency[e1].add(e0)
        
        # TO DO: Optimize
        print('Building vert2edge map..')
        index = 0
        # set to -1 if edge is not there
        self.vert2edg = -1*np.ones((self.nverts, self.nverts))
        for i, j in np.ndindex(self.faces.shape):
            e0, e1 = self.faces[i, j], self.faces[i, (j+1)%3]
            if self.vert2edg[e0,e1] < 0:
                self.vert2edg[e0,e1] = index
                self.vert2edg[e1,e0] = index
                index+=1
        
        # count edges in mesh  
        self.nedges = np.sum(self.vert2edg >= 0)//2
        
        
        edges_facenormals = [[] for _ in range(self.nedges)]
        for i, j in np.ndindex(self.faces.shape):
            # extract vertices connected by edge
            e0, e1 = self.faces[i, j], self.faces[i, (j+1)%3] 
            edges_facenormals[self.vert2edg[e0, e1].astype(int)].append(face_normals[i, :])
        
        #is waterthight?
        irregular_edges = ([ i for i in range(self.nedges) if len(edges_facenormals[i]) == 1 ])
        if len(irregular_edges) > 0:
            print("Mesh is not watertight!")
                            
        # compute second order difference score on edges  
        self.SODvertscore = np.zeros(self.nverts,)
        
        self.SODedgescore = [ np.arccos(np.dot(edges_facenormals[i][0],edges_facenormals[i][1])) if len(edges_facenormals[i])>1 else 0.0 for i in range(self.nedges) if len(edges_facenormals[i] ) ]
        
        # propagate sod information to vertices
        
        for e0 in range(self.nverts):
            for e1 in self.adjacency[e0]:
                self.SODvertscore[e0] += self.SODedgescore[self.vert2edg[e0, e1].astype(int)]
            self.SODvertscore[e0] /= len(self.adjacency[e0])    
        
            
        print('Mesh generated: vertices = %i, faces = %i ' % (self.nverts, self.nfaces))
        
        
    def apply_rototranslation(self,R,t):
        for i in range(self.nverts): 
            self.vertices[i, :] = (R.dot(self.vertices[i, :]) + t)
        self.refresh_normals()
        
    def apply_scalingtranslation(self,S,t):
        for i in range(self.nverts):  
            self.vertices[i, :] = (S.dot(self.vertices[i, :]) + t)
        self.refresh_normals()
        
    def refresh_normals(self):
        v = [self.vertices[self.faces[:, i], :] for i in range(3)]
        face_normals = np.cross(v[2] - v[0], v[1] - v[0])
        face_normals /= np.linalg.norm(face_normals, axis=1)[:, None]
        self.face_normals = face_normals
        self.normals = np.zeros((self.nverts, 3))
        # mean of sorrounding face normals
        for i, j in np.ndindex(self.faces.shape):
            self.normals[self.faces[i, j], :] += self.face_normals[i, :]
        self.normals /= np.linalg.norm(self.normals, axis=1)[:, None]
        
        edges_facenormals = [[] for _ in range(self.nedges)]
        for i, j in np.ndindex(self.faces.shape):
            # extract vertices connected by edge
            e0, e1 = self.faces[i, j], self.faces[i, (j+1)%3] 
            edges_facenormals[self.vert2edg[e0, e1].astype(int)].append(self.face_normals[i, :])
                            
        # compute second order difference score on edges  
        self.SODvertscore = np.zeros(self.nverts,)
        
        self.SODedgescore = [ np.arccos(np.dot(edges_facenormals[i][0],edges_facenormals[i][1])) if len(edges_facenormals[i])>1 else 0.0 for i in range(self.nedges) if len(edges_facenormals[i] ) ]
        
        # propagate sod information to vertices

        for e0 in range(self.nverts):
            for e1 in self.adjacency[e0]:
                self.SODvertscore[e0] += self.SODedgescore[self.vert2edg[e0, e1].astype(int)]
            self.SODvertscore[e0] /= len(self.adjacency[e0])    
               
        print('refreshed normals')
        
        
    def compute_target_normals(self):
        
        sod_threshold = 0.25
        
        target_normals = np.zeros((self.nverts, 3))
     
        for i in range(self.nverts):
            # extract current normal
            n = self.normals[i, :]
            # define target normal
            target_n = np.zeros((3,))
            # find closest axis
            index = np.argmax(np.abs(n))
            # set orientation
            
            #ugly hack
            #if self.vertices[i, 0]>2200 and index == 2 :
             #   target_n[0] = +1
            #else:
            target_n[index] = np.sign(n[index])*1
            
            
            target_normals[i, :] = target_n
        
       
        # post process feature points
        for e0 in range(self.nverts):
            if self.SODvertscore[e0] > sod_threshold:
                n = 0
                tgt_n = np.zeros((3,))
                for e1 in self.adjacency[e0]:
                    if self.SODvertscore[e0] <= sod_threshold:
                        tgt_n[e0, :] += tgt_n[e1, :]
                        n+=1
                if n>0:
                    target_normals[e0, :]= tgt_n/n
        
        
        #smooth things out
        target_normals = utils.smooth_vector_field(self,target_normals,n_iter = 20,lambda_ = -0.1)

            
        return target_normals
    
    
    def compute_rotation_field(self):

        target_normals = self.compute_target_normals()
        rotation_field = np.zeros((self.nverts, 3, 3))
        
        for i in range(self.nverts):
            # extract current normal
            n = self.normals[i, :]
            # extract target normal
            t = target_normals[i,:]
            # compute rotation
            rotation_field[i,:,:] = utils.get_rotation_matrix(n,t)          
            
            #print(n)  
            #print(n) 
            #print(rotation_field[i,:,:]) 
        
        return rotation_field
    
    
    def assemble_poisson_system(self):
        
        target_normals = self.compute_target_normals()
        rotation_field = self.compute_rotation_field()
        
        # pin 1 vertex in order to not have singular system
        rhs = np.eye(self.nverts)
        lhs_x = np.ones((self.nverts,))
        lhs_y = np.ones((self.nverts,))
        lhs_z = np.ones((self.nverts,))
        
        pinned_vertex = 0
        #pinned_vertex = random.choice(range(self.nverts))
        
        # use adjacency matrix to assemble rhs,lhs
        for i in range(self.nverts):
            if i is not pinned_vertex:
                # extract current normal
                N = len(self.adjacency[i])
                sum_lhs = 0
                for j in self.adjacency[i]:
                    rhs[i,j] = -1.0/N
                    sum_lhs+= np.dot(rotation_field[i,:,:] + rotation_field[j,:,:], self.vertices[i, :] - self.vertices[j,:] )
                lhs_x[i] = (1/(2*N))*sum_lhs[0]
                lhs_y[i] = (1/(2*N))*sum_lhs[1]
                lhs_z[i] = (1/(2*N))*sum_lhs[2]
                
        
        return rhs,lhs_x,lhs_y,lhs_z
    
    def align_normals(self, iterations = 1):
        for i in range(iterations):
            print('Aligning normals (%i/%i) ..' % (i+1, iterations))
            rhs,lhs_x,lhs_y,lhs_z = self.assemble_poisson_system()
            x = np.linalg.solve(rhs, lhs_x)
            y = np.linalg.solve(rhs, lhs_y)
            z = np.linalg.solve(rhs, lhs_z)         
            print ('Solved linear systems..')
            # update vertex positions
            for i in range(self.nverts):
                self.vertices[i, 0] = x[i]
                self.vertices[i, 1] = y[i]
                self.vertices[i, 2] = z[i]
            self.refresh_normals()
            
    def compute_bounding_box(self):
        
        min_x = np.min(self.vertices[:,0])
        max_x = np.max(self.vertices[:,0])
        min_y = np.min(self.vertices[:,1])
        max_y = np.max(self.vertices[:,1])
        min_z = np.min(self.vertices[:,2])
        max_z = np.max(self.vertices[:,2])
        
        return [min_x,max_x,min_y,max_y,min_z,max_z]
    
    def scale(self,scaling_factor):
        self.vertices*= scaling_factor
        self.refresh_normals()
        
    def update_vertices(self,coords):
        self.vertices= coords
        self.refresh_normals()
    
    
    def closest_point_projection(self,pointcloud):
        closest_points = np.zeros(pointcloud.shape)
        min_distances = np.zeros((pointcloud.shape[0],))
        simplex_indices = np.zeros((pointcloud.shape[0],))
        barycentric_cordinates = np.zeros((pointcloud.shape[0],2))
        
        for i in range(pointcloud.shape[0]):
            p = pointcloud[i,:]
            min_dist = 10000
            print('Working on point ', i)
            for j in range(self.nfaces):
                n = self.face_normals[j,:]
                # find nearest point on plane
                projected = p - np.dot(p,n)*n
                
                
                
                #Compute vectors        
                v0 = self.vertices[self.faces[j, 2]] - self.vertices[self.faces[j, 0]]
                v1 = self.vertices[self.faces[j, 1]] - self.vertices[self.faces[j, 0]]
                v2 = projected - self.vertices[self.faces[j, 0]]

                #Compute dot products
                dot00 = np.dot(v0, v0)
                dot01 = np.dot(v0, v1)
                dot02 = np.dot(v0, v2)
                dot11 = np.dot(v1, v1)
                dot12 = np.dot(v1, v2)
                

                # Compute barycentric coordinates
                invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
                u = (dot11 * dot02 - dot01 * dot12) * invDenom
                v = (dot00 * dot12 - dot01 * dot02) * invDenom
               
                # if point lies inside triangle
                if u >= 0 and v >= 0 and u+v <= 1:
                    nearest = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                # if point lies otside triangle correct projection
                if u < 0 and v < 0:
                    u=0
                    v=0
                    nearest = self.vertices[self.faces[j, 0]]
                elif u > 0 and v > 0 and u+v> 1:
                    uplusv = u+v
                    u/= uplusv
                    v/= uplusv
                    nearest = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                elif u > 1 and v < 0:
                    u=1
                    v=0
                    nearest = self.vertices[self.faces[j, 2]]
                elif v > 1 and u < 0:
                    u=0
                    v=1
                    nearest = self.vertices[self.faces[j, 1]]
                elif u < 1 and v < 0:
                    v = 0
                    nearest = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                    #nearest_out = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                    #t = v0/np.linalg.norm(v0)
                    #nearest = self.vertices[self.faces[j, 0]] + np.dot(nearest_out,t)*t
                    #v=0
                    #u = np.linalg.norm(np.dot(nearest_out,t)*t)/np.linalg.norm(v0)
                    
                    
                elif u < 0 and v < 1:
                    u = 0
                    nearest = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                    
                    #nearest_out = self.vertices[self.faces[j, 0]] + u*v0 + v*v1
                    #t = v1/np.linalg.norm(v1)
                    #nearest = self.vertices[self.faces[j, 0]] + np.dot(nearest_out,t)*t
                    #u=0
                    #v = np.linalg.norm(np.dot(nearest_out,t)*t)/np.linalg.norm(v1)
                    
                
                dist = np.linalg.norm(p-nearest)
                
                if  dist < min_dist:
                    min_dist = dist
                    closest_points[i,:] = nearest 
                    simplex_indices[i] = j
                    barycentric_cordinates[i,0] = u
                    barycentric_cordinates[i,1] = v
        
            min_distances[i] = min_dist
                    
        return closest_points, simplex_indices, barycentric_cordinates, min_distances
    
    
    
    def export_for_tensorflow(self,outfile = 'cube.npy'):
        vertices_sorted = self.vertices[self.sort_map,:]
        vertices = vertices_sorted[self.inverse_map,:]
        # compute reshaping factor
        faces = np.split(vertices,6)
        vertices = [face.reshape(self.shape_resolution+1,self.shape_resolution+1,3) for face in faces]
        np.save(outfile, vertices)
        
    
                
                

##############################
# VISUALIZATION
##############################

    def visualize(self,colormap=cm.RdBu, plot_edges=None,plot_normals=None,plot_clustered = None,plot_features = None, sod_=0.3, plot_field=None, field=None, quad_mesh = None):
        
        #x, y, z are lists of coordinates of the triangle vertices 
        #faces are the simplices that define the triangularization
        # normals are vertex normals
        x = self.vertices[:,0]
        y = self.vertices[:,1]
        z = self.vertices[:,2]
        #x,y,z = zip(*self.vertices)
        simplices = self.faces
        normals = self.normals
        
        points3D=np.vstack((x,y,z)).T
        points3D = points3D.reshape((-1,3))
        
        sod = self.SODvertscore;
        
        # map defining vertices of the surface triangles
        tri_vertices=map(lambda index: points3D[index], simplices)
        
        # mean values of z-coordinates of triangle vertices                                      
        zmean=[np.mean(tri[:,2]) for tri in tri_vertices ]
        min_zmean=np.min(zmean)
        max_zmean=np.max(zmean)  
        # use it for color mapping
        if plot_field is None:
            facecolor=[utils.map_z2color(zz,  colormap, min_zmean, max_zmean) for zz in zmean] 
        elif plot_field is True:
            fmean= [1/3*(field[simplex[0]]+field[simplex[1]]+field[simplex[2]]) for simplex in simplices ]
            min_f=np.min(fmean)
            max_f=np.max(fmean)  
            facecolor=[utils.map_field2color(f,  colormap, min_f, max_f) for f in fmean]
        
        # get indices of triangles
        I,J,K=utils.tri_indices(simplices)

        triangles=go.Mesh3d(x=x,
                         y=y,
                         z=z,
                         #facecolor='rgb(150,170,150)', 
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


        if plot_edges is None:# the triangle sides are not plotted 
            return iplot(fig)
        else:
            #define the lists Xe, Ye, Ze, of x, y, resp z coordinates of edge end points for each triangle
            #None separates data corresponding to two consecutive triangles
            #lists_coord=[[[T[k%3][c] for k in range(4)]+[ None]   for T in tri_vertices]  for c in range(3)]
            # refresh map
            
            if quad_mesh:
                n_pts = 4
                
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_x=[[T[k%3][0] for k in range(0,n_pts) if k is not 1 ]+[None]   for T in tri_vertices]
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_y=[[T[k%3][1] for k in range(0,n_pts) if k is not 1]+[None]   for T in tri_vertices]  
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_z=[[T[k%3][2] for k in range(0,n_pts) if k is not 1]+[None]   for T in tri_vertices] 
                
            else:
                n_pts = 4
            
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_x=[[T[k%3][0] for k in range(0,n_pts)]+[None]   for T in tri_vertices]
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_y=[[T[k%3][1] for k in range(0,n_pts)]+[None]   for T in tri_vertices]  
                tri_vertices=map(lambda index: points3D[index], simplices)
                lists_coord_z=[[T[k%3][2] for k in range(0,n_pts)]+[None]   for T in tri_vertices] 

            lists_coord = [lists_coord_x,lists_coord_y,lists_coord_z]

            Xe, Ye, Ze=[functools.reduce(lambda x,y: x+y, lists_coord[k]) for k in range(3)]

            #define the lines to be plotted
            lines=go.Scatter3d(x=Xe,
                            y=Ye,
                            z=Ze,
                            mode='lines',
                            line=go.Line(color= 'rgb(50,50,50)', width=1.5)
                   )
            
            if plot_normals is None:
                
                layout = go.Layout(
                    xaxis=dict(
                        autorange=True,
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        autotick=True,
                        ticks='',
                        showticklabels=False
                    ),
                    yaxis=dict(
                        autorange=True,
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        autotick=True,
                        ticks='',
                        showticklabels=False
                    )
                )
                
               
                data =  go.Data([triangles, lines])
                fig = go.Figure(data=data, layout=layout)
                fig['layout'].update(
                    scene=dict(
                        xaxis=dict(
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        showticklabels=False,
                        showaxeslabels=False,
                        title = ''),
                        yaxis=dict(
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        showticklabels=False,
                        showaxeslabels=False,
                        title = ''),
                        zaxis=dict(
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        showticklabels=False,
                        showaxeslabels=False,
                        title = ''),
                    )
                )
                
                #py.image.save_as(fig, filename='fig.pdf')
                iplot(fig, filename="Input mesh")
                return
            else:
                #define the lists Xe, Ye, Ze, of x, y, resp z coordinates of edge end points for each triangle
                #None separates data corresponding to two consecutive triangles

                normal_length_factor = (max_zmean - min_zmean)/6
                
                
                if plot_features is True:
                    # make them a bit smaller then normals
                    normal_length_factor/=3
                    lists_coord_x= [[v] + [v-normal_length_factor*n[0]] + [None]   for (v,n,s) in zip(x,normals,sod) if s>sod_ ]
                    lists_coord_y= [[v] + [v-normal_length_factor*n[1]] + [None]   for (v,n,s) in zip(y,normals,sod) if s>sod_ ] 
                    lists_coord_z= [[v] + [v-normal_length_factor*n[2]] + [None]   for (v,n,s) in zip(z,normals,sod) if s>sod_ ]
                    
                    
                    
                    lists_coord = [lists_coord_x,lists_coord_y,lists_coord_z]
                    
                    if len(lists_coord[0]) == 0:
                        Xn, Yn, Zn = [], [], []
                    else:
                        Xn, Yn, Zn=[functools.reduce(lambda x,y: x+y, lists_coord[k]) for k in range(3)]
                    normals=go.Scatter3d(x=Xn,
                                y=Yn,
                                z=Zn,
                                mode='lines',
                                line=go.Line(color= 'rgb(200,90,130)', width=6.0)
                       )
                
                
                else :
                    lists_coord_x= [[v] + [v-normal_length_factor*n[0]] + [None]   for (v,n) in zip(x,normals)]
                    lists_coord_y= [[v] + [v-normal_length_factor*n[1]] + [None]   for (v,n) in zip(y,normals)] 
                    lists_coord_z= [[v] + [v-normal_length_factor*n[2]] + [None]   for (v,n) in zip(z,normals)] 
                    lists_coord = [lists_coord_x,lists_coord_y,lists_coord_z]
                    Xn, Yn, Zn=[functools.reduce(lambda x,y: x+y, lists_coord[k]) for k in range(3)]
                    normals=go.Scatter3d(x=Xn,
                                y=Yn,
                                z=Zn,
                                mode='lines',
                                line=go.Line(color= 'rgb(50,205,50)', width=4.0)
                       )

                
                layout = go.Layout(
                    xaxis=dict(
                        autorange=True,
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        autotick=True,
                        ticks='',
                        showticklabels=False
                    ),
                    yaxis=dict(
                        autorange=True,
                        showgrid=False,
                        zeroline=False,
                        showline=False,
                        autotick=True,
                        ticks='',
                        showticklabels=False
                    )
                )
                
               
                    
                data =  go.Data([triangles, lines, normals])
                fig = go.Figure(data=data, layout=layout)
                    
                return iplot(fig)
                        
"""
    
# needed for debugging only
      
    def visualize_target_normals(self,plot_edges=None, plot_normals = None):
        x,y,z = zip(*self.vertices)
        faces = self.faces
        normals = mesh.compute_target_normals()
        
        fig2 = self.plotly_trisurf(x,y,z, faces,normals, colormap=cm.RdBu, plot_edges=plot_edges,plot_normals=plot_normals)
        
        iplot(fig2, filename="Input mesh")
        
        
    def cluster_normal_field(self,n_clusters = 6):
        # whiten data out
        whitened_data = cluster.whiten(self.normals)
        # returns codebook, distortion
        code_book, distortion = cluster.kmeans(whitened_data, n_clusters)
        # map data to cluster label
        self.cluster_label = cluster.vq(whitened_data, code_book)
"""     
   
            