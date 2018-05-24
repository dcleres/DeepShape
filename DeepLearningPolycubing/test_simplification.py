import matplotlib
matplotlib.use("nbagg")

import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D

from utility import *
from models import *

from os import listdir
from os.path import isfile, join
import numpy as np
import math

import torch.optim as optim

polycube_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/Generated-Cars-Grid_size100/"
polycube_files = [f for f in listdir(polycube_path) if isfile(join(polycube_path, f))]

voxelized_mesh_path = "/Users/davidcleres/DeepShape/Polycubing-Automated/voxelizedMeshes-Grid_size100/"
voxelized_mesh_files = [f for f in listdir(voxelized_mesh_path) if isfile(join(voxelized_mesh_path, f))]

voxelizedFiles = []
polycubedFiles = []

for f in voxelized_mesh_files: 
    if f[-13:] == "voxelized.txt":
        voxelizedFiles = np.hstack((voxelizedFiles, f))
    
for f in polycube_files:
    if f[-14:] == "finalCubes.txt":
        polycubedFiles = np.hstack((polycubedFiles, f))
        
grid_size = 100
voxelized_train_input, polycube_target=loadData(grid_size, polycube_path, voxelized_mesh_path, voxelizedFiles, polycubedFiles, loadFromScratch=False)

batch_size = 5 
preprocessed_input_train, preprocessed_input_validation, preprocessed_input_train_target, preprocessed_input_validation_target = preprocessing_train(voxelized_train_input, polycube_target,batch_size, False, False)

preprocessed_input_train = torch.from_numpy(preprocessed_input_train)
preprocessed_input_validation = torch.from_numpy(preprocessed_input_validation)
preprocessed_input_train_target = torch.from_numpy(preprocessed_input_train_target)
preprocessed_input_validation_target = torch.from_numpy(preprocessed_input_validation_target)

Ntrain = len(preprocessed_input_train[:,0,0,0,0]) 
Nvalidation = len(preprocessed_input_validation[:,0,0,0,0])
image_size = 100

train_input = np.array(preprocessed_input_train.view(Ntrain, 1,image_size, image_size, image_size))
validation_input = np.array(preprocessed_input_validation.view(Nvalidation, 1,image_size, image_size, image_size))

labels_train = np.array(preprocessed_input_train_target.view(Ntrain, 1, image_size, image_size, image_size))
labels_validation = np.array(preprocessed_input_validation_target.view(Nvalidation, 1,image_size, image_size, image_size))

labels_train_cube_coords = np.zeros((len(train_input[:,0,0,0,0]), 1, 9))
for i in range (len(train_input[:,0,0,0,0])):
    #solution 1 - the loss is calculed based on the 9 labels 
    delta_x_left, delta_x_right, center_x, delta_y_left, delta_y_right, center_y, delta_z_left, delta_z_right, center_z = find_center_and_delta(labels_train[i, 0, :, :, :], grid_size=100)
    labels_train_cube_coords[i,0,0] = delta_x_left
    labels_train_cube_coords[i,0,1] = delta_x_right
    labels_train_cube_coords[i,0,2] = center_x
    labels_train_cube_coords[i,0,3] = delta_y_left
    labels_train_cube_coords[i,0,4] = delta_y_right
    labels_train_cube_coords[i,0,5] = center_y
    labels_train_cube_coords[i,0,6] = delta_z_left
    labels_train_cube_coords[i,0,7] = delta_z_right
    labels_train_cube_coords[i,0,8] = center_z
    
labels_validation_cube_coords = np.zeros((len(labels_validation[:,0,0,0,0]), 1, 9))
for i in range (len((validation_input[:,0,0,0,0]))):
    #solution 1 - the loss is calculed based on the 9 labels 
    delta_x_left, delta_x_right, center_x, delta_y_left, delta_y_right, center_y, delta_z_left, delta_z_right, center_z = find_center_and_delta(labels_train[i, 0, :, :, :], grid_size=100)
    labels_validation_cube_coords[i, 0,0] = delta_x_left
    labels_validation_cube_coords[i, 0,1] = delta_x_right
    labels_validation_cube_coords[i, 0,2] = center_x
    labels_validation_cube_coords[i, 0,3] = delta_y_left
    labels_validation_cube_coords[i, 0,4] = delta_y_right
    labels_validation_cube_coords[i, 0,5] = center_y
    labels_validation_cube_coords[i, 0,6] = delta_z_left
    labels_validation_cube_coords[i,0,7] = delta_z_right
    labels_validation_cube_coords[i, 0,8] = center_z
    
    
labels_validation_cube_coords = torch.from_numpy(labels_validation_cube_coords)
labels_train_cube_coords = torch.from_numpy(labels_train_cube_coords)
train_input = torch.from_numpy(train_input)
validation_input = torch.from_numpy(validation_input)

print('train_input', train_input.shape)
print('labels_train_cube_coords', labels_train_cube_coords.shape)
print('validation_input', validation_input.shape)
print('labels_validation_cube_coords', labels_validation_cube_coords.shape)

    
    #solution 2 - the loss is calculated from the cube generated thanks to the learned coordinates 
    #output = build_cube(delta_x_left, delta_x_right, center_x, delta_y_left, delta_y_right, center_y, delta_z_left, delta_z_right, center_z, grid_size)
    

# Train network 
#criterion = nn.BCELoss()
#criterion = nn.CrossEntropyLoss()
#criterion = nn.PoissonNLLLoss()
#criterion = nn.BCEWithLogitsLoss()
#criterion = nn.SmoothL1Loss()
criterion = nn.MSELoss()

train_input = Variable(train_input).float()
validation_input = Variable(validation_input).float()

if isinstance(criterion, nn.CrossEntropyLoss):
    train_target = Variable(labels_train_cube_coords)  # keep long tensors
    validation_target = Variable(labels_validation_cube_coords, 
    uires_grad=False) # convert to float
    Noutputs = 18
    
elif isinstance(criterion, nn.NLLLoss):
    train_target = Variable(labels_train_cube_coords)  # keep long tensors
    validation_target = Variable(labels_validation_cube_coords, requires_grad=False) # convert to float
    Noutputs = 18
    
else:
    train_target = Variable(labels_train_cube_coords, requires_grad=False).float() # convert to float
    validation_target = Variable(labels_validation_cube_coords, requires_grad=False).float() # convert to float
    Noutputs = 9

batch_size = 5
Nbatches = int(math.ceil(Ntrain/batch_size))
Nepochs = 10
#seeds = list(range(15)) #Test 15 different seeds but always the seeds from 0 to 15 so that the weights are always initialized in a reproducible way
#Nrep = len(seeds)
Nrep = 1

train_errors = torch.Tensor(Nrep, Nepochs).zero_()
test_errors = torch.Tensor(Nrep, Nepochs).zero_()
validation_errors = torch.Tensor(Nrep, Nepochs).zero_()
ep_loss = torch.Tensor(Nrep, Nepochs).zero_()


for i_rep in range(Nrep):    
    #print('Repetition', seeds[i_rep])
    #torch.manual_seed(seeds[i_rep])
    
    #model = conv2DNet_1(Nchannels, Nsamples_100, Noutputs) #from litterature EEG-Net coorected
    model = conv2DNet_2(Noutputs)  #from Temporal - Spatial; 4 Filters Model - Best performing model with accuracy 0.83 in average on the validation set
    #model = conv2DNet_3(Noutputs) #from Temporal - Spatial; 64 Filters Model
    #model = conv2DNet_4(Noutputs) #from Temporal - Spatial; 128 Filters Model
    
    #optimizer = optim.SGD(model.parameters(), lr=1e-3, momentum=0.50)
    optimizer = optim.Adam(model.parameters())
    #optimizer = optim.Adagrad(model.parameters())
    #optimizer = optim.Adamax(model.parameters())
    #optimizer = optim.ASGD(model.parameters())
    #optimizer = optim.RMSprop(model.parameters())
    #optimizer = optim.Rprop(model.parameters())
    
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, 'min', patience=10, verbose=True) #Reduces the learning rate if it did not decreased by more than 10^-4 in 10 steps

    for i_ep in range(Nepochs):
        predict = torch.Tensor(0, 9).zero_()
        for b_start in range(0, Ntrain, batch_size):
            bsize_eff = batch_size - max(0, b_start+batch_size-Ntrain)  # boundary case
            model.train()
            model.zero_grad()
            output = model(train_input.narrow(0, b_start, bsize_eff))
            if isinstance(criterion, nn.CrossEntropyLoss) or isinstance(criterion, nn.NLLLoss):
                batch_loss = criterion(output, train_target.narrow(0, b_start, bsize_eff))
            else:
                batch_loss = criterion(output.view(bsize_eff*Noutputs), train_target.narrow(0, b_start, bsize_eff))
            ep_loss[i_rep, i_ep] += batch_loss.data[0]
            batch_loss.backward()
            optimizer.step()
            
            predict = torch.cat((predict, output.data), 0)
    
        torch.save(predict, 'prediction_MSE_25.pth')
        scheduler.step(ep_loss[i_rep, i_ep])
        
        '''nb_train_errs = compute_nb_errors(model, train_input, train_target, batch_size, criterion)
        nb_validation_errs = compute_nb_errors(model, validation_input, validation_target, batch_size, criterion)'''
        
        print("Epoch Number : ", i_ep)
        '''print("\t Training accuracy: ", (100*(Ntrain-nb_train_errs)/Ntrain))
        print("\t Validation accuracy ",(100*(Nvalidation-nb_validation_errs)/Nvalidation))'''
        
        print("\t Epoch Loss ", ep_loss[i_rep, i_ep])
        
        '''train_errors[i_rep, i_ep] = nb_train_errs
        validation_errors[i_rep, i_ep] = nb_validation_errs
        
train_accuracy = 100*(Ntrain-np.array(train_errors))/Ntrain
val_accuracy = 100*(Nvalidation-np.array(validation_errors))/Nvalidation

stddev_train_errors = np.std(train_accuracy, axis=0)
stddev_val_errors = np.std(val_accuracy, axis=0)

mean_train_errors = np.mean(train_accuracy, axis=0)
mean_val_errors = np.mean(val_accuracy, axis=0)

epoch = list(range(50))
plt.plot(epoch, mean_train_errors)
plt.plot(epoch, mean_val_errors)
plt.fill_between(epoch, mean_train_errors+stddev_train_errors, mean_train_errors-stddev_train_errors, alpha=0.5)
plt.fill_between(epoch, mean_val_errors+stddev_val_errors, mean_val_errors-stddev_val_errors, alpha=0.5)
plt.xlabel('Number of epochs')
plt.ylabel('Accuracy in %')
plt.legend(['train', 'validation', 'test'])

print("Training accuracy {:4.3g}%+-{}".format(mean_train_errors[-1], stddev_train_errors[-1]))
print("Validation accuracy {:4.3g}%+-{}".format(mean_val_errors[-1], stddev_val_errors[-1]))'''
