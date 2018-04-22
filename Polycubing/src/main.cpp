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
            igl::writeSTL("pseudo.stl", U,F);
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
            Timer timer;
            
            //Fixed grid size each time
            int gridSize = 100; //Cf Edoardo's ML file
            int numThread = 4; //atoi(argv[2]);
            string inputFile = "/Users/davidcleres/DeepShape/Polycubing/data/pseudo_camaro.stl";
            string outputFileForView = "/Users/davidcleres/DeepShape/Polycubing/data/kawada-hironx.binvox";
            string outputFileWrite = "/Users/davidcleres/DeepShape/Polycubing/data/kawada-hironx-compressed.vox";
            string outputFileWriteSimple = "/Users/davidcleres/DeepShape/Polycubing/data/kawada-hironx-simple.vox";
            
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
            
            int voting(5);
            int sliceNumber(50);
            
            voxelizer.writeTextFile();
            voxelizer.writeSliceTextFile(sliceNumber);
            voxelizer.writeVotingToTextFile(voxelizer.voting(voting, voxelizer.getBinarytensor()));
            voxelizer.writeSliceVotingTextFile(sliceNumber, voxelizer.voting(voting, voxelizer.getBinarytensor()));
            voxelizer.writeSliceTextFile(voxelizer.findRegionalMaxima(3, voxelizer.voting(voting, voxelizer.getBinarytensor())), voting);
            voxelizer.writeTextFile(voxelizer.findRegionalMaxima(3, voxelizer.voting(voting, voxelizer.getBinarytensor())));
            
            timer.Stop();
            cout << "writing file "; timer.PrintTimeInS();
            cout << "-------------------------------------------" << endl;
            
            //voxelizer.openCV();
            
            vector<vector<vector<int> > > counterMatrix = vector<vector<vector<int> > > (gridSize, vector<vector<int> >(gridSize, vector<int>(gridSize, 0)));
            
            voxelizer.writeTextFile(voxelizer.neighbourhoodCorrection(3, counterMatrix), "neighbors");
            voxelizer.writeSliceTextFile(voxelizer.neighbourhoodCorrection(3, counterMatrix), sliceNumber, "neighbors");
            
            voxelizer.writeSliceVotingTextFile(sliceNumber, counterMatrix, "Counter");
            voxelizer.writeSliceVotingTextFile(sliceNumber, voxelizer.voting(voting, voxelizer.neighbourhoodCorrection(3, counterMatrix)), "newVoting");
            voxelizer.writeSliceTextFile(voxelizer.findBorders(voxelizer.voting(voting, voxelizer.neighbourhoodCorrection(3, counterMatrix))), sliceNumber, "means");
            
            voxelizer.writeSliceTextFileXProj(voxelizer.voting(voting, voxelizer.neighbourhoodCorrection(3, counterMatrix)), 39, "xproj");
            
            voxelizer.writeTextFileXProj(39);
            voxelizer.writeTextFile(voxelizer.findBorders(voxelizer.voting(voting, voxelizer.neighbourhoodCorrection(3, counterMatrix))),  "final"); //HERE
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
        filename = "/Users/davidcleres/DeepShape/Polycubing/models/camaro.off";
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
