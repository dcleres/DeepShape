import matplotlib
matplotlib.use("nbagg")

import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D

from utility import *
from models import *

import math

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

from os import listdir
from os.path import isfile, join
import numpy as np

onCluster = True

if onCluster:
    polycube_path = "/home/cleres/anaconda3/DeepShape/Polycubing-Automated/Generated-Cars/"
    polycube_files = [f for f in listdir(polycube_path) if isfile(join(polycube_path, f))]
    
    voxelized_mesh_path = "/home/cleres/anaconda3/DeepShape/Polycubing-Automated/voxelizedMeshes/"
    voxelized_mesh_files = [f for f in listdir(voxelized_mesh_path) if isfile(join(voxelized_mesh_path, f))]

else:
    polycube_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/Generated-Cars/"
    polycube_files = [f for f in listdir(polycube_path) if isfile(join(polycube_path, f))]
    
    voxelized_mesh_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/voxelizedMeshes/"
    voxelized_mesh_files = [f for f in listdir(voxelized_mesh_path) if isfile(join(voxelized_mesh_path, f))]

voxelizedFiles = []
polycubedFiles = []

for f in voxelized_mesh_files: 
    if f[-13:] == "voxelized.txt":
        voxelizedFiles = np.hstack((voxelizedFiles, f))
    
for f in polycube_files:
    if f[-14:] == "finalCubes.txt":
        polycubedFiles = np.hstack((polycubedFiles, f))
        
#Definition of the global paramters
grid_size=32
batch_size=5


# Save the tensor to a text file 
voxelized_train_input, polycube_target=loadData(grid_size, polycube_path, voxelized_mesh_path, voxelizedFiles, polycubedFiles, loadFromScratch=True)

#Create a Training and a Validation Set 
preprocessed_input_train, preprocessed_input_validation, preprocessed_input_train_target, preprocessed_input_validation_target = preprocessing_train(voxelized_train_input, polycube_target,batch_size, False, False)

preprocessed_input_train = torch.from_numpy(preprocessed_input_train)
preprocessed_input_validation = torch.from_numpy(preprocessed_input_validation)
preprocessed_input_train_target = torch.from_numpy(preprocessed_input_train_target)
preprocessed_input_validation_target = torch.from_numpy(preprocessed_input_validation_target)

Ntrain = len(preprocessed_input_train[:, 0,0,0,0]) 
Nvalidation = len(preprocessed_input_validation[:,0,0,0,0])

train_input = Variable(preprocessed_input_train.view(Ntrain, 1, grid_size, grid_size, grid_size).float())
validation_input = Variable(preprocessed_input_validation.view(Nvalidation, 1, grid_size, grid_size, grid_size).float())

labels_train = preprocessed_input_train_target.float()
labels_validation = preprocessed_input_validation_target.float()

print('train', train_input.shape)
print('validation', validation_input.shape)
print('train_target', labels_train.shape)
print('validation_target', labels_validation.shape)

#Init the neural network 
# Train network 
#criterion = nn.BCELoss()
criterion = nn.CrossEntropyLoss()
#criterion = nn.PoissonNLLLoss()
#criterion = nn.BCEWithLogitsLoss()
#criterion = nn.SmoothL1Loss() #interesting ... but does not converge
#criterion = nn.MSELoss() #0.83 but unstable

if isinstance(criterion, nn.CrossEntropyLoss):
    train_target = Variable(preprocessed_input_train_target).long()  # keep long tensors
    validation_target = Variable(preprocessed_input_validation_target, volatile=True).long() # convert to float
    Noutputs = 2
    
elif isinstance(criterion, nn.NLLLoss):
    train_target = Variable(preprocessed_input_train_target)  # keep long tensors
    validation_target = Variable(preprocessed_input_validation_target, volatile=True) # convert to float
    Noutputs = 2
    
else:
    train_target = Variable(preprocessed_input_train_target.float()) # convert to float
    validation_target = Variable(preprocessed_input_validation_target.float(), volatile=True ) # convert to float
    Noutputs = 1
    
Nbatches = int(math.ceil(Ntrain/batch_size)) #batch_size is defined above
Nepochs = 500
Nrep = 1
        
#model = conv3DNet(grid_size, Noutputs, batch_size)
#model = conv3DNet(grid_size, Noutputs, batch_size)
#model = conv3DNet(grid_size, Noutputs, batch_size)
#model = conv3DNet(grid_size, Noutputs, batch_size)
model = UnetGenerator_3d(in_dim=1, out_dim=Noutputs, num_filter=4)

#optimizer = optim.SGD(model.parameters(), lr=1e-2, momentum=0.90)
#optimizer = optim.Adam(model.parameters())
#optimizer = optim.Adagrad(model.parameters())
optimizer = optim.Adamax(model.parameters())
#optimizer = optim.ASGD(model.parameters())
#optimizer = optim.RMSprop(model.parameters())
#optimizer = optim.Rprop(model.parameters())
 
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, 'min', patience=10, verbose=True) #Reduces the learning rate if it did not decreased by more than 10^-4 in 10 steps

train_errors = torch.Tensor(Nepochs).zero_()
validation_errors = torch.Tensor(Nepochs).zero_()

ep_loss = torch.Tensor(Nepochs).zero_()

for i_ep in range(Nepochs):
    for b_start in range(0, Ntrain, batch_size):
        bsize_eff = batch_size - max(0, b_start+batch_size-Ntrain)  # boundary case
        model.train()
        model.zero_grad()
        output = model(train_input.narrow(0, b_start, bsize_eff))
        if isinstance(criterion, nn.CrossEntropyLoss) or isinstance(criterion, nn.NLLLoss):
            batch_loss = criterion(output, train_target.narrow(0, b_start, bsize_eff))
        else:
            #if delta model is chosen
            #batch_loss = criterion(output.view(bsize_eff*Noutputs), train_target.narrow(0, b_start, bsize_eff))
            batch_loss = criterion(output.view(bsize_eff,grid_size,grid_size,grid_size), train_target.narrow(0, b_start, bsize_eff))
        ep_loss[i_ep] += batch_loss.data[0]
        batch_loss.backward()
        optimizer.step()

    scheduler.step(ep_loss[i_ep])

    nb_train_errs = compute_nb_errors(model, train_input, train_target, batch_size, criterion)
    nb_validation_errs = compute_nb_errors(model, validation_input, validation_target, batch_size, criterion)

    Ntrain_nb = Ntrain*grid_size**3
    Nvalidation_nb = Nvalidation*grid_size**3
    print("Epoch Number : ", i_ep)
    print("\t Training accuracy: ", (100*(Ntrain_nb-nb_train_errs)/Ntrain_nb))
    print("\t Validation accuracy ",(100*(Nvalidation_nb-nb_validation_errs)/Nvalidation_nb))

    print("\t Epoch Loss ", ep_loss[i_ep])

    train_errors[i_ep] = nb_train_errs
    validation_errors[i_ep] = nb_validation_errs
    
training_accuracy = np.array(100*(Ntrain_nb-train_errors)/Ntrain_nb)
validation_accurcy = np.array(100*(Nvalidation_nb-validation_errors)/Nvalidation_nb)
np.save('training_accuracy_Adamax', training_accuracy)
np.save('validation_accuracy_Adamax', validation_accurcy)

plt.plot(training_accuracy)
plt.plot(validation_accurcy)
plt.savefig('Conv3D - Polycubes-Grid_size32-CE-Sigmoid-Adamax.png')
plt.show()

test_visualisation = output[14,1,:,:,:].round()

voxels = np.array(test_visualisation.data)

# and plot everything
fig = plt.figure(figsize=(10,10))
ax = fig.gca(projection='3d')
ax.voxels(voxels)
fig.savefig('VoxelizedFinal.png')
fig.show()
