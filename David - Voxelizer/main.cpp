#define VOXEL_RES 0.5

#include <igl/opengl/glfw/Viewer.h>
#include <igl/readOFF.h>
#include <igl/readOBJ.h>

#include <igl/writeSTL.h>

#include <igl/mat_max.h>
#include <igl/per_vertex_normals.h>
#include <igl/per_face_normals.h>
#include <igl/per_corner_normals.h>
#include <igl/edges.h>
#include <igl/jet.h>
#include <iostream>
#include <Eigen/Geometry>
#include <Eigen/Dense>
#include <Eigen/IterativeLinearSolvers>

#define VOXELIZER_IMPLEMENTATION
#include "voxelizer.h"


using namespace Eigen;
using namespace std;

// input mesh
Eigen::MatrixXd V,U;
Eigen::MatrixXi F;
std::vector<std::vector<double> > A;

// voxelized mesh
Eigen::MatrixXd U_;
Eigen::MatrixXi F_;

Eigen::MatrixXd color_map;
Eigen::MatrixXd target_vertices;

Eigen::VectorXd RHS_x;
Eigen::VectorXd RHS_y;
Eigen::VectorXd RHS_z;

Eigen::SparseMatrix<double> lap,LHS;


const auto &key_down = [](igl::opengl::glfw::Viewer &viewer,unsigned char key,int mod)->bool
{
    switch(key)
    {
        case 'r':
        case 'R':
            //cout << "resetting to starting mesh." << endl;
            U = V;
            
            viewer.data().set_vertices(U);
            viewer.data().compute_normals();
            viewer.core.align_camera_center(U,F);
            break;
        case 's':
        case 'S':
            cout << "Saving to STL." << endl; //Saves the displayed model to the build folder
            igl::writeSTL("pseudo.stl", U, F);
            break;
        case ' ': //Computes the normal vectors to rotate the face onto a plane axis
        {
            // Compute per-vertex normals
            Eigen::MatrixXd normals_vertices;
            //igl::PerVertexNormalsWeightingType weighting = igl::PER_VERTEX_NORMALS_WEIGHTING_TYPE_UNIFORM;
            igl::per_vertex_normals(U,F, normals_vertices);
            
            // Compute closest axis
            Eigen::VectorXi maxIndices;
            Eigen::VectorXf maxVals;
            igl::mat_max(normals_vertices.cwiseAbs(),2,maxVals,maxIndices);
            Eigen::MatrixXd target_vertices = Eigen::MatrixXd::Zero(normals_vertices.rows(),normals_vertices.cols());
            for (int i = 0; i < normals_vertices.rows(); i++)
            {
                target_vertices(i,maxIndices(i)) = (normals_vertices(i,maxIndices(i)) > 0) ? 1.0 : -1.0;
            }
            // Smooth field out
            double lambda_ = -0.1;
            for (int j = 0; j < 2; j++)
            {
                for (int i = 0; i < 3; i++)
                {
                    target_vertices.col(i) += lap* target_vertices.col(i);
                }
            }
            
            // Compute rotation field
            std::vector<Eigen::MatrixXd> rotations;
            for (int i = 0; i < normals_vertices.rows(); i++)
            {
                Eigen::VectorXd n = normals_vertices.row(i);
                Eigen::VectorXd t = target_vertices.row(i);
                Eigen::Quaterniond Q = Eigen::Quaterniond().setFromTwoVectors(n,t);
                Eigen::Matrix3d R = Q.toRotationMatrix();
                rotations.push_back(R);
            }
            
            
            // Assemble Linear Systems
            RHS_x = Eigen::VectorXd::Ones(normals_vertices.rows());
            RHS_y = Eigen::VectorXd::Ones(normals_vertices.rows());
            RHS_z = Eigen::VectorXd::Ones(normals_vertices.rows());
            
            // Pin vertex to make system solvable
            int pinned_i = 0;
            for (int i = 0; i < normals_vertices.rows(); i++)
            {
                if (i != pinned_i)
                {
                    int N = A[i].size();
                    Eigen::VectorXd sum_lhs = Eigen::VectorXd::Zero(normals_vertices.cols());
                    for (int j : A[i] )
                    {
                        sum_lhs += (rotations[i] + rotations[j])*((U.row(i) - U.row(j)).transpose());
                    }
                    RHS_x(i) = (0.5/N)*sum_lhs(0);
                    RHS_y(i) = (0.5/N)*sum_lhs(1);
                    RHS_z(i) = (0.5/N)*sum_lhs(2);
                }
            }
            
            // Solve sparse linear systems
            Eigen::BiCGSTAB<SparseMatrix<double> >  BCGST;
            BCGST.compute(LHS);
            //cout << RHS_x << endl;
            
            Eigen::VectorXd x = BCGST.solve(RHS_x);
            Eigen::VectorXd y = BCGST.solve(RHS_y);
            Eigen::VectorXd z = BCGST.solve(RHS_z);
            
            // Update mesh
            U.col(0) = x;
            U.col(1) = y;
            U.col(2) = z;
            
            
            // Send new positions, update normals, recenter
            viewer.data().set_vertices(U);
            viewer.data().compute_normals();
            viewer.core.align_camera_center(U,F);
            break;
        }
        case 'v':       //Surface Voxelizes what is diplayed on the screen
        case 'V':
        {
            /*
            //TODO: generate cube
            vx_mesh_t* mesh;
            vx_mesh_t* result;
            vx_point_cloud_t* result_pc;
            
            mesh = vx_mesh_alloc( U.rows(), 3*F.rows() );
            
            // fill in vertices
            for (size_t v = 0; v < U.rows(); v++)
            {
                mesh->vertices[v].x = U(v,0);
                mesh->vertices[v].y = U(v,1);
                mesh->vertices[v].z = U(v,2);
            }
            // fill in faces
            for (size_t f = 0; f < F.rows(); f++)
            {
                mesh->indices[3*f] = F(f,0);
                mesh->indices[3*f+1] = F(f,1);
                mesh->indices[3*f+2] = F(f,2);
            }
            
            
            // Precision factor to reduce "holes" artifact, experimenting with 2*eta
            //float precision = 0.01;
            
            // get bounding box
            // Find the bounding box
            Eigen::Vector3d m = U.colwise().minCoeff();
            Eigen::Vector3d M = U.colwise().maxCoeff();
            
            cout << "computing suitable voxel resolution..." << endl;
            cout << "bounding box diagonal: " << endl;
            cout << (M - m).norm() << endl;
            float eta = (M - m).norm()/20;
            cout << "voxel size: " << eta << endl;
            
            
            // Run voxelization for visualization
            result = vx_voxelize(mesh, eta, eta, eta, eta*2);
            result_pc = vx_voxelize_pc(mesh, eta, eta, eta, eta*2);
            
            cout << "Voxelized mesh..." << "n_voxels-- " << result->nvertices/8 << endl;
            /*cout << "PC Voxelized mesh..." << "n_voxels-- " << result_pc->nvertices << endl;
             for (size_t v = 0; v < result_pc->nvertices; v++)
             {
             cout << result_pc->vertices[v].x << "\t" << result_pc->vertices[v].y << "\t" << result_pc->vertices[v].z << endl;
             }*/

            /*
   
            //Copy back to data structurs for visualization
            U_ = Eigen::MatrixXd::Zero(result->nvertices,3) ;
            F_ = Eigen::MatrixXi::Zero(int(result->nindices/3),3);
            
            // fill in vertices
            for (size_t v = 0; v < U_.rows(); v++)
            {
                U_(v,0) =  result->vertices[v].x;
                U_(v,1) =  result->vertices[v].y;
                U_(v,2) =  result->vertices[v].z;
            }
            // fill in faces
            for (size_t f = 0; f < F_.rows(); f++)
            {
                F_(f,0) = result->indices[3*f];
                F_(f,1) = result->indices[3*f+1];
                F_(f,2) = result->indices[3*f+2];
            }
            
            vx_mesh_free(result);
            vx_mesh_free(mesh);
            */

            Timer timer;
            //Fixed grid size each time
            int gridSize = 100; //Cf Edoardo's ML file
            int numThread = 4; //atoi(argv[2]);
            string inputFile = "../data/pseudo_camaro.stl";
            string outputFile = "../kawada-hironx.binvox";

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
            //U_ = voxelizer.WriteSimple(outputFile);    //Enables to write a file in the vox format
            //voxelizer.write(outputFile);
            voxelizer.WriteForView(outputFile); //Enables to write a file in the binvox format
            timer.Stop();
            cout << "writing file "; timer.PrintTimeInS();
            cout << "-------------------------------------------" << endl;



            /*//GET THE VERTEX COORDINATES OF THE VOXELS
            // Update mesh
            U_.col(0) = x; // X IS A 1D VECTOR
            U_.col(1) = y;
            U_.col(2) = z;

            viewer.data().clear();
            viewer.data().set_mesh(U_,F_);
            viewer.core.align_camera_center(U_,F_);
            break;*/
        }
            
        default:
            return false;
    }
    return true;
};


int main(int argc, char *argv[])
{
    
    std::string filename;
    if (argc > 1)
    {
        filename = std::string(argv[1]);
    }
    else
    {
        filename = "../models/camaro.off";
    }
    
    // Load a mesh in OFF format
    igl::readOFF(filename, V, F);
    //igl::readOBJ("../models/bunny.obj", V, F);
    
    // compute adjacency list
    igl::adjacency_list(F,A);
    
    // assemble Laplacian Matrix
    lap = Eigen::SparseMatrix<double>(V.rows(),V.rows());
    lap.setIdentity();
    for (int i = 0; i < V.rows(); i++)
    {
        int N = A[i].size();
        for (int j : A[i] )
        {
            lap.insert(i,j) = -1.0/N;
            
        }
    }
    
    // assemble modified Laplacian for linear system
    LHS= Eigen::SparseMatrix<double>(V.rows(),V.rows());
    LHS.setIdentity();
    int pinned_i = 0;
    for (int i = 0; i < V.rows(); i++)
    {
        if(i!=pinned_i)
        {
            int N = A[i].size();
            for (int j : A[i] )
            {
                LHS.insert(i,j) = -1.0/N;
            }
        }
    }
    
    // Plot the mesh
    igl::opengl::glfw::Viewer viewer;
    // Initialize smoothing with base mesh
    U = V;
    viewer.data().set_mesh(U, F);
    viewer.data().compute_normals();
    // use z coordinate for color map
    Eigen::VectorXd Z = U.col(2);
    igl::jet(Z,true,color_map);
    //viewer.data.set_colors(color_map);
    viewer.callback_key_down = key_down;
    cout<<"Press [space] to align normals"<<endl;
    cout<<"Press [r] to reset"<<endl;
    cout<<"Press [s] to save as STL file"<<endl;
    cout<<"Press [v] to voxelize"<<endl;
    viewer.launch();
}
