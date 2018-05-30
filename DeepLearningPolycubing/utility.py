import numpy as np 
from scipy import signal
import matplotlib.pyplot as plt
import random, os, torch, scipy

import torch
import torch.nn as nn
import torch.utils as utils
import torch.nn.init as init
import torch.utils.data as data
import torchvision.utils as v_utils
import torchvision.datasets as dset
import torchvision.transforms as transforms
from torch.autograd import Variable
from torch import Tensor

import torch.optim as optim
import torch.nn.functional as F

#uploads the data-sets have been downscaled to a 100Hz sampling rate
def importData(filename, grid_size):
    train_input = load(root = './Polycubing/data/', filename = filename, grid_size = grid_size)
    print(str(type(train_input)), train_input.size()) 
    #print(str(type(train_target)), train_target.size())
    '''test_input , test_target = load(root = './data_bci_100Hz', train = False)
    print(str(type(test_input)), test_input.size()) 
    print(str(type(test_target)), test_target.size())'''
    
    return train_input #, train_target, test_input, test_target


#uploads the data-sets have been downscaled to a 100Hz sampling rate
def importDataAutomated(filename, grid_size):
    train_input = load(root = './Polycubing-Automated/Generated-Cars/', filename = filename, grid_size = grid_size)
    print(str(type(train_input)), train_input.size()) 
    #print(str(type(train_target)), train_target.size())
    '''test_input , test_target = load(root = './data_bci_100Hz', train = False)
    print(str(type(test_input)), test_input.size()) 
    print(str(type(test_target)), test_target.size())'''
    
    return train_input #, train_target, test_input, test_target

def tensor_from_file(root, filename):

    file_path = os.path.join(root, filename)

    if not os.path.exists(file_path):
        try:
            os.makedirs(root)
        except OSError as e:
            if e.errno == errno.EEXIST:
                pass
            else:
                raise

        print('Loading ' + filename)

    return torch.from_numpy(np.loadtxt(file_path))

def load(root, filename, grid_size, train = True):
    """
    Args:
        root (string): Root directory of dataset.
        train (bool, optional): If True, creates dataset from training data.
        download (bool, optional): If True, downloads the dataset from the internet and
            puts it in root directory. If dataset is already downloaded, it is not
            downloaded again.
        one_khz (bool, optional): If True, creates dataset from the 1000Hz data instead
            of the default 100Hz.
    """

    nb_electrodes = grid_size #selected grid size 
    

    #if train: #the first coloumns is a label coloumn 

    '''dataset = tensor_from_file(root, filename)
    input = dataset.narrow(1, 1, dataset.size(1) - 1)
    input = input.float().view(input.size(0), nb_electrodes, -1)
    target = dataset.narrow(1, 0, 1).clone().view(-1).long()'''

    #else:
    input = tensor_from_file(root, filename)
    #target = tensor_from_file(root, 'labels_data_set_iv.txt')

    #input = input.float().view(input.size(0), nb_electrodes, -1) #Load Float Data
    input = input.int().view(input.size(0), nb_electrodes, -1) #Load Float Data
    #target = target.view(-1).long()

    return input#, target
    
def cross_validation(dataset):
    
    idxToDelete = np.random.choice(dataset, 16)
    print(idxToDelete)
    
    lengthDataSet = len(dataset[:,0,0])
    
    print(len(dataset[:,0,0]))
    print(lengthDataSet/4)
    
    x1=np.delete(dataset,range(0,int(lengthDataSet/4)),axis=0)
    x2=np.delete(dataset,range(int(lengthDataSet/4),int(2*lengthDataSet/4)),axis=0)
    x3=np.delete(dataset,range(int(2*lengthDataSet/4),int(3*lengthDataSet/4)),axis=0)
    x4=np.delete(dataset,range(int(3*lengthDataSet/4),int(lengthDataSet)),axis=0)

    return x1, x2, x3, x4

def cross_validation_labels(dataset):
    
    lengthDataSet = len(dataset)
    
    y1=np.delete(dataset,range(0,int(lengthDataSet/4)),axis=0)
    y2=np.delete(dataset,range(int(lengthDataSet/4),int(2*lengthDataSet/4)),axis=0)
    y3=np.delete(dataset,range(int(2*lengthDataSet/4),int(3*lengthDataSet/4)),axis=0)
    y4=np.delete(dataset,range(int(3*lengthDataSet/4),int(lengthDataSet)),axis=0)

    return y1, y2, y3, y4


def standardize(centered_tX):
    centered_tX[centered_tX==0] = float('nan')
    stdevtrain = np.nanstd(centered_tX, axis=0)
    centered_tX[centered_tX==float('nan')] = 0
    stdevtrain[stdevtrain == 0] = 0.00001
            #CHECK WHY IT IS HAPPENING
    standardized_tX = centered_tX / stdevtrain
    return standardized_tX, stdevtrain

def standardize_original(tX):
    # Removing bothering data and centering
    tX[tX==-999] = 0
    s_mean = np.mean(tX, axis=0)
    centered_tX = tX - s_mean
    stdtX, stdevtrain = standardize(centered_tX)

    return stdtX, stdevtrain, s_mean

def standardize_basis(tX):
    # Resetting all the data
    b_mean = np.mean(tX,axis=0)
    centered_mat = tX - b_mean
    centered_mat[tX==0] = 0
    standardized_tX, stdevtrain = standardize(centered_mat)

    return standardized_tX, stdevtrain, b_mean

def standardize_test_original(tX, training_original_mean, stdevtrain):
    tX[tX==-999] = 0
    centered_testx = tX - training_original_mean
    centered_testx[tX==-999] = 0
    standardized_testx = centered_testx / stdevtrain

    return standardized_testx

def standardized_testx_basis(tX, basis_original_mean, stdev):
    centered_mat = tX - basis_original_mean
    centered_mat[tX==0] = 0
    standardized_testmat = centered_mat / stdev

    return standardized_testmat

"""
Returns a polynomial basis formed of all the degrees and combinations.
- The first part of the code computes from degree 1 to a given degree (max d=15)
- The second part of the code, computes the second degree with combinations meanning
that is combines every feature with each other in order to make paramters like the PHI angles
more meaningful.
- Finally, The last one is the third degree basis with combinations of elements
that do not all have the same degree, and only taking the 15 first most meaningful
features for our model. 
"""
def build_poly_basis(tx):
    d = len(tx[0])
    n = len(tx)

    indices_s_deg = []
    indices_t_deg = []

    print("Creating indices for subsets of degree 2")
    for i in range (d):
        for t in range (i,d):
            indices_s_deg.append([t, i])
    indices_s_deg = np.array(indices_s_deg).T

    print("Creating indices for subsets of degree 3")
    max_t_degree = min(d-1,15)
    for i in range (max_t_degree):
        for t in range (i,max_t_degree):
            for j in range(t,max_t_degree):
                if not (i == t and i == j):
                    indices_t_deg.append([j, t, i])
    indices_t_deg = np.array(indices_t_deg).T

    degrees = range(3,11)
    degrees_number = len(degrees) + 1
    stdX_Ncols = tx.shape[1]
    indices_s_Ncols = indices_s_deg.shape[1]
    indices_t_Ncols = indices_t_deg.shape[1]

    number_of_rows = indices_s_Ncols + degrees_number * stdX_Ncols + indices_t_Ncols

    mat = np.zeros((n, number_of_rows))

    print("Computing first degree")
    # First degree
    mat[:, :stdX_Ncols] = tx

    print("Computing second degree WITH combinations")
    # Second degree gotten from indices
    mat[:,stdX_Ncols:stdX_Ncols + indices_s_Ncols] = tx[:, indices_s_deg[0]] * tx[:, indices_s_deg[1]]

    print("Computing from degree 3 to 10 WITHOUT combinations...")
    # Improve 3 to 10 degree
    for i in degrees:
        start_index = indices_s_Ncols + (i - 2) * stdX_Ncols
        end_index = start_index + stdX_Ncols
        mat[:,start_index:end_index] = tx**i

    print("Computing third degree WITH combinations...")
    # Third degree gotten from indices
    mat[:, number_of_rows - indices_t_Ncols: number_of_rows] = tx[:, indices_t_deg[0]] * tx[:, indices_t_deg[1]] * tx[:, indices_t_deg[2]]

    return mat

def noise(X, intensity): 
    # Adding white noise
    wn = np.random.randn(len(X), len(X[0, :]))
    return X + intensity*wn

def denoisedSignals(inputData): 
    #IMPORTANT !! needs to be computationnally optimized by using the operations shown in the exercises 
    
    normalizedOutput = np.zeros(inputData.shape)
    numberSamples = (np.array(inputData[:, 0, 0])).size
    numberElectrodes = (np.array(inputData[0, :, 0])).size

    for i in range (0, numberSamples): 
        for j in range (0, numberElectrodes): 
            signal = np.array(inputData[i, j, :])        
            data = np.array(signal)

            fft=scipy.fft(data) #signal denoising 
            bp=fft[:]
            for p in range(len(bp)): 
                if p>=10:
                    bp[p]=0
            ibp=scipy.ifft(bp)

            #ibp = (ibp-ibp[0])/max(max(ibp), abs(min(ibp))) #signal normalization with initial offset suprresion 
            ibp = (ibp-np.mean(ibp))/np.std(ibp) #signal normalization with initial offset suprresion 
            
            normalizedOutput[i,j,:] = ibp.real
    return normalizedOutput

def preprocessing_train(train_input, train_target, batch_size, denoize=False, addGaussianNoise=False):
    
    #denoise and normalize data (without detrending and so)
    tmp = np.array(train_input).copy()
    tmp_target = np.array(train_target).copy()
    
    if denoize:
        tmp = denoisedSignals(tmp) #Deletes the high frequencies 

    idxToDelete = random.sample(range(len(tmp[:,0,0,0])), batch_size) #takes 16 lines as a validation set
    augmented_train_input_validation = tmp[idxToDelete,:,:,:,:]
    augmented_train_input_validation_target = tmp_target[idxToDelete,:,:,:]
    augmented_train_input_train = np.delete(tmp, idxToDelete, 0)
    augmented_train_input_train_target = np.delete(tmp_target, idxToDelete, 0)
    
    final_augmented_train_input_train = augmented_train_input_train
    final_augmented_train_input_validation = augmented_train_input_validation
    final_augmented_train_input_train_target = augmented_train_input_train_target
    final_augmented_train_input_validation_target = augmented_train_input_validation_target

    if(addGaussianNoise):
        noise_tensor = np.zeros(final_augmented_train_input_train.shape)
        for i in range (final_augmented_train_input_train.shape[0]):
            noiseIntensity = 0.1*np.max(final_augmented_train_input_train[i,:,:])
            noise_tensor[i, :, :] = noise(final_augmented_train_input_train[i,:,:], noiseIntensity)
        return noise_tensor, final_augmented_train_input_validation, final_augmented_train_input_train_target, final_augmented_train_input_validation_target
    
    return final_augmented_train_input_train, final_augmented_train_input_validation, final_augmented_train_input_train_target, final_augmented_train_input_validation_target

def preprocessing_test(test_input, denoize = False):
    #denoise and normalize data (without detrending and so)
    tmp = np.array(test_input)
    if denoize:
        tmp = denoisedSignals(tmp)
    return tmp

def loadData(grid_size, polycube_path, voxelized_mesh_path, voxelizedFiles, polycubedFiles, loadFromScratch=False):
    if loadFromScratch: 
        voxelized_train_input = importDataAutomated(filename = voxelized_mesh_path+str(voxelizedFiles[0]), grid_size=grid_size)
        polycube_target =  importDataAutomated(filename = polycube_path+str(polycubedFiles[0]), grid_size=grid_size)

        voxelized_train_input = voxelized_train_input.view(1, 1, grid_size, grid_size, grid_size) #add a dimension of the 3D convolution
        polycube_target = polycube_target.view(1, grid_size, grid_size, grid_size)

        for i in range(1, 600):#len(voxelizedFiles)):
            voxelized_train_input = torch.cat((voxelized_train_input, importDataAutomated(filename = voxelized_mesh_path+str(voxelizedFiles[i]), grid_size=grid_size).view(1, 1, grid_size, grid_size, grid_size)), 0)
            polycube_target = torch.cat((polycube_target, importDataAutomated(filename = polycube_path+str(polycubedFiles[i]), grid_size=grid_size).view(1, grid_size, grid_size, grid_size)), 0)

        print(polycube_target.shape)
        torch.save(voxelized_train_input, 'Loaded_Files/voxelized_train_input.pth')
        torch.save(polycube_target, 'Loaded_Files/polycube_target.pth')
    else: 
        voxelized_train_input = torch.load('Loaded_Files/voxelized_train_input.pth')
        polycube_target = torch.load('Loaded_Files/polycube_target.pth')
        
    return voxelized_train_input, polycube_target

def compute_nb_errors(model, data_input, data_target, batch_size, criterion):
    nb_errors = 0
    Ndata = len(data_input[:, 0, 0, 0, 0])
    for b_start in range(0, Ndata, batch_size):
        bsize_eff = batch_size - max(0, b_start+batch_size-Ndata)  # boundary case
        batch_output = model(data_input.narrow(0, b_start, bsize_eff))  # is Variable if data_input is Variable
        if isinstance(criterion, nn.CrossEntropyLoss) or isinstance(criterion, nn.NLLLoss): #if CrossEntropy
            nb_errors += int((batch_output.max(1)[1] != data_target.narrow(0, b_start, bsize_eff)).long().sum())
        else: 
            err_matrix = batch_output.round().view(batch_size,32,32,32)-data_target.narrow(0, b_start, bsize_eff) #should give 0 if same and ±1 if not the same
            nb_errors += int(torch.sum(torch.abs(err_matrix).view(-1)))
    return nb_errors

def compute_nb_errors_delta(model, data_input, data_target, batch_size, criterion):
    nb_errors = 0
    Ndata = len(data_input[:, 0, 0, 0, 0])
    for b_start in range(0, Ndata, batch_size):
        bsize_eff = batch_size - max(0, b_start+batch_size-Ndata)  # boundary case
        batch_output = model(data_input.narrow(0, b_start, bsize_eff))  # is Variable if data_input is Variable
        if isinstance(criterion, nn.CrossEntropyLoss) or isinstance(criterion, nn.NLLLoss): #if CrossEntropy
            nb_errors += int((batch_output.max(1)[1] != data_target.narrow(0, b_start, bsize_eff)).long().sum())
        else:             
            #print('batch_output', batch_output.shape)
            #print('data_target.narrow(0, b_start, bsize_eff)', data_target.narrow(0, b_start, bsize_eff).shape)
            nb_errors = batch_output.round().sub(data_target.narrow(0, b_start,bsize_eff).view(bsize_eff,9)).sign().abs().sum()
    return int(nb_errors)

def is_in_boudaries(x, y, z, grid_size): 
    return x < grid_size and y < grid_size and z < grid_size

def find_center_and_delta(labels_train, grid_size):
    for x in range (grid_size): 
        for y in range (grid_size): 
            for z in range (grid_size): 
                if labels_train[x, y, z] == 1:
                    x_init = x 
                    y_init = y
                    z_init = z
                    delta_x_left=0
                    delta_x_right=0 
                    delta_y_left=0
                    delta_y_right=0 
                    delta_z_left=0
                    delta_z_right=0
                    
                    while (is_in_boudaries(x, y, z, grid_size) and labels_train[x, y, z] == 1): 
                        x=x+1
                    if not(is_in_boudaries(x, y, z, grid_size)): 
                        x=x-1 
                    delta_x=int((x-x_init)/2)
                    delta_x_rest=int((x-x_init)%2)    
                    center_x=int(x_init+delta_x)
                    if delta_x_rest == 1: #we have a rest of one on one size 
                        if labels_train[center_x-delta_x-1, y, z] == 1: 
                            delta_x_left=delta_x+1
                            delta_x_right=delta_x
                        else:
                            delta_x_left=delta_x
                            delta_x_right=delta_x+1
                    else:
                        delta_x_left=delta_x
                        delta_x_rigth=delta_x

                    while (is_in_boudaries(center_x, y, z, grid_size) and labels_train[center_x, y, z] == 1): 
                        y=y+1
                    if not(is_in_boudaries(center_x, y, z, grid_size)): 
                        y=y-1 
                    delta_y=int((y-y_init)/2)
                    delta_y_rest=int((y-y_init)%2)
                    center_y=int(y_init+delta_y)
                    if delta_y_rest == 1: #we have a rest of one on one size 
                        if labels_train[center_x, center_y-delta_y-1, z] == 1: 
                            delta_y_left=delta_y+1
                            delta_y_right=delta_y
                        else:
                            delta_y_left=delta_y
                            delta_y_right=delta_y+1
                    else: 
                        delta_y_left=delta_y
                        delta_y_right=delta_y

                    while (is_in_boudaries(center_x, center_y, z, grid_size) and labels_train[center_x, center_y, z] == 1): 
                        z=z+1
                    if not(is_in_boudaries(center_x, center_y, z, grid_size)): 
                        z=z-1 
                    delta_z=int((z-z_init)/2)
                    delta_z_rest=int((z-z_init)%2)
                    center_z=int(z_init+delta_z)
                    if delta_z_rest == 1: #we have a rest of one on one size 
                        if labels_train[center_x, center_y, z] == 1: 
                            delta_z_left=delta_z+1
                            delta_z_right=delta_z
                        else:
                            delta_z_left=delta_z
                            delta_z_right=delta_z+1
                    else: 
                        delta_z_left=delta_z
                        delta_z_right=delta_z
                        
                    return delta_x_left, delta_x_right, center_x, delta_y_left, delta_y_right, center_y, delta_z_left, delta_z_right, center_z
                     
def build_cube(delta_x_left, delta_x_right, center_x, delta_y_left, delta_y_right, center_y, delta_z_left, delta_z_right, center_z, grid_size): 
    output = np.zeros((grid_size, grid_size, grid_size))
    for x in range(-delta_x_left+center_x,delta_x_right+center_x):
        for y in range(-delta_y_left+center_y,delta_y_right+center_y):
            for z in range(-delta_z_left+center_z,delta_z_right+center_z):
                output[x, y, z] = 1
    return output   