import matplotlib
matplotlib.use("nbagg")

import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D

from utility import *
from model import *

import torch
import torch.nn as nn
import torch.utils as utils
import torch.nn.init as init
import torch.utils.data as data
import torchvision.utils as v_utils
import torchvision.datasets as dset
import torchvision.transforms as transforms
from torch.autograd import Variable

from os import listdir
from os.path import isfile, join
import numpy as np
import math

polycube_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/Generated-Cars-Grid_size64/"
polycube_files = [f for f in listdir(polycube_path) if isfile(join(polycube_path, f))]

voxelized_mesh_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/voxelizedMeshes-Grid_size64/"
voxelized_mesh_files = [f for f in listdir(voxelized_mesh_path) if isfile(join(voxelized_mesh_path, f))]

voxelizedFiles = []
polycubedFiles = []

for f in voxelized_mesh_files: 
    if f[-13:] == "voxelized.txt":
        voxelizedFiles = np.hstack((voxelizedFiles, f))
    
for f in polycube_files:
    if f[-14:] == "finalCubes.txt":
        polycubedFiles = np.hstack((polycubedFiles, f))
        
grid_size = 64
voxelized_train_input, polycube_target=loadData(grid_size, polycube_path, voxelized_mesh_path, voxelizedFiles, polycubedFiles, loadFromScratch=False)
       
batch_size = 5 
preprocessed_input_train, preprocessed_input_validation, preprocessed_input_train_target, preprocessed_input_validation_target = preprocessing_train(voxelized_train_input, polycube_target,batch_size, False, False)

preprocessed_input_train = torch.from_numpy(preprocessed_input_train)
preprocessed_input_validation = torch.from_numpy(preprocessed_input_validation)
preprocessed_input_train_target = torch.from_numpy(preprocessed_input_train_target)
preprocessed_input_validation_target = torch.from_numpy(preprocessed_input_validation_target)

Ntrain = len(preprocessed_input_train[:, 0,0,0,0]) 
Nvalidation = len(preprocessed_input_validation[:,0,0,0,0])
image_size = 64

train_input = Variable(preprocessed_input_train.view(Ntrain, 1, image_size, image_size, image_size).float())
validation_input = Variable(preprocessed_input_validation.view(Nvalidation, 1, image_size, image_size, image_size).float())

labels_train = Variable(preprocessed_input_train_target.view(Ntrain, 1, image_size, image_size, image_size), requires_grad=False).float() 
labels_validation = Variable(preprocessed_input_validation_target.view(Nvalidation, 1, image_size, image_size, image_size), requires_grad=False).float() 

print('train', train_input.shape)
print('validation', validation_input.shape)
print('train_target', labels_train.shape)
print('validation_target', labels_validation.shape)

#model = nn.Conv3d(in_channels=1, out_channels=1, kernel_size=3, stride=1, padding=1,bias=True)
#model(train_input).size()

unet = UnetGenerator_3d(in_dim=1,out_dim=1,num_filter=4)

#output = unet(train_input)
#print(output.size()) 

Nepochs = 5
Nrep = 1

# Train network 
criterion = nn.BCELoss()
#criterion = nn.CrossEntropyLoss()
#criterion = nn.PoissonNLLLoss()
#criterion = nn.BCEWithLogitsLoss()
#criterion = nn.SmoothL1Loss() #interesting ... but does not converge
#criterion = nn.MSELoss() #0.83 but unstable

#optimizer = optim.SGD(unet.parameters(), lr=1e-2, momentum=0.90)
optimizer = optim.Adam(unet.parameters())
#optimizer = optim.Adagrad(unet.parameters())
#optimizer = optim.Adamax(unet.parameters())
#optimizer = optim.ASGD(unet.parameters())
#optimizer = optim.RMSprop(unet.parameters())
#optimizer = optim.Rprop(unet.parameters())

scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, 'min', patience=10, verbose=True)

train_errors = torch.Tensor(Nepochs).zero_()
validation_errors = torch.Tensor(Nepochs).zero_()

ep_loss = torch.Tensor(Nepochs).zero_()

for i_rep in range(Nrep):
    for i_ep in range(Nepochs):
        for b_start in range(0, Ntrain, batch_size):
            bsize_eff = batch_size - max(0, b_start+batch_size-Ntrain)  # boundary case
            unet.train()
            unet.zero_grad()
            output = unet(train_input.narrow(0, b_start, bsize_eff))
            batch_loss = criterion(output, labels_train.narrow(0, b_start, bsize_eff))            
            ep_loss[i_ep] += batch_loss.data[0]
            batch_loss.backward()
            optimizer.step()
        
        scheduler.step(ep_loss[i_ep])
        
        print("\t Epoch Loss ", ep_loss[i_ep])
        
        nb_train_errs = compute_nb_errors(unet, train_input, labels_train, batch_size)
        nb_validation_errs = compute_nb_errors(unet, validation_input, labels_validation, batch_size)
        
        print("train_error", nb_train_errs)
        print("nb_validation_errs", nb_validation_errs)
        
        print("Epoch Number : ", i_ep)
        print("\t Training accuracy: ", np.abs(100*(Ntrain*100*100*100-int(nb_train_errs))/(Ntrain*100*100*100)))
        print("\t Validation accuracy ", np.abs(100*(Nvalidation*100*100*100-int(nb_validation_errs))/(Nvalidation*100*100*100))) 
        
        print("\t Epoch Loss ", ep_loss[i_ep])
        
        train_errors[i_ep] = int(nb_train_errs)
        validation_errors[i_ep] = int(nb_validation_errs)

    voxels = np.array(output[4,:,:,:])

    # and plot everything
    fig = plt.figure(figsize=(10,10))
    ax = fig.gca(projection='3d')
    ax.voxels(voxels)
    fig.savefig('VoxelizedFinal.png')
