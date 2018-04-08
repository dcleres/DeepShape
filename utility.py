# This is distributed under BSD 3-Clause license
import torch
import numpy
import os
import errno

from six.moves import urllib

#uploads the data-sets have been downscaled to a 100Hz sampling rate
def importData(filename, grid_size):
    train_input = load(root = './Data', filename = filename, grid_size = grid_size)
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

    return torch.from_numpy(numpy.loadtxt(file_path))

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