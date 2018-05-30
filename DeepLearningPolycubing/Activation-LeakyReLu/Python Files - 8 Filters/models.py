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

# DC U-Net
class conv3DNet_1(nn.Module):
    def __init__(self, gridSize, output_units, batch_size):
        """Initializes neural network with 3 convolutional layers and 1 fully-connected layer.
        
        Args:
            - Nchannels (int): number of EEG channels
            - Nsamples (int): number of time points in each EEG signal
            - output_units (int): number of output units, e.g. 1 for training with loss torch.nn.BCELoss or 2 with 
            loss torch.nn.CrossEntropyLoss            
            """
        super(conv3DNet, self).__init__()
        
        Noutputs = 1
        self.fc_linear = 1020 * gridSize**3
        self.batch_size = batch_size
        self.output_units=output_units
        
        '''# Layer 1
        l1_channels = 16
        self.conv1 = nn.Conv3d(1, l1_channels, kernel_size=3, padding = 1)
        self.batchnorm1 = nn.BatchNorm3d(l1_channels, False) # final size bsize x 1 x l1_channels x Nsamples
        self.pooling1 = nn.MaxPool3d(kernel_size=2, padding=1)'''
        
        # Layer 2
        l2_channels = 32
        self.conv2 = nn.Conv3d(1, l2_channels, kernel_size=3, padding = 1, stride = 1)
        self.batchnorm2 = nn.BatchNorm3d(l2_channels, False) # final size bsize x 1 x l1_channels x Nsamples
        self.pooling2 = nn.MaxPool3d(kernel_size=2)
        
        '''# Layer 3
        l3_channels = 64
        self.conv3 = nn.Conv3d(l2_channels, l3_channels, kernel_size=3, padding = 1, stride = 1)
        self.batchnorm3 = nn.BatchNorm3d(l3_channels, False) # final size bsize x 1 x l1_channels x Nsamples
        self.pooling3 = nn.MaxPool3d(kernel_size=2)
        
        self.up1 = nn.ConvTranspose3d(l3_channels, l2_channels, kernel_size=2, stride=2)'''
        self.up2 = nn.ConvTranspose3d(l2_channels, self.output_units,kernel_size=2, stride=2)
    
    def forward(self, x):
        """Applies forward pass consisting of 3 convolutional layers followed by a fully-connected linear layer.
        
        Args:
            - x (torch.autograd.Variable): the input batch. It has dimension batch_size x Nchannel x Nsamples x 1,
            where Nchannel is the number of EEG channels and Nsamples the number of time points.
        
        Returns:
            - (torch.autograd.Variable) of size either batch_size x output_units   
        
        """ 
        print(x.shape)

        '''# Layer 1
        x = F.relu(self.conv1(x))              # bsize x l1_channels x 1 x Nsamples
        x = self.batchnorm1(x)
        x = F.dropout(x, 0.3)
        #x = self.pooling1(x)
        print(x.shape)'''

        # Layer 2
        x = F.relu(self.conv2(x))              # bsize x l2_channels x l1_channels x Nsamples
        x = self.batchnorm2(x)       
        x = F.dropout(x, 0.3)
        x = self.pooling2(x)                  # bsize x l2_channels x floor(l1_channels/2) x floor(Nsamples/4)
        print(x.shape)
        
        '''# Layer 3
        #x = self.padding1(x)
        x = F.relu(self.conv3(x))              # bsize x l2_channels x l1_channels x Nsamples
        x = self.batchnorm3(x)       
        x = F.dropout(x, 0.3)
        x = self.pooling3(x)                  # bsize x l2_channels x floor(l1_channels/2) x floor(Nsamples/4)
        print(x.shape)
        
        x =  F.relu(self.up1(x))
        print(x.shape)'''
        x =  F.relu(self.up2(x))
        print(x.shape)
        x = F.softmax(x)
        
        x = x.view(15, self.output_units, gridSize, gridSize, gridSize)
        
        return x

#find the coordinates of the center and the deltas 
class conv2DNet_2(nn.Module):
    def __init__(self, output_units):
        super(conv2DNet_2, self).__init__()
        
        #4*1*54 for 125 HZ 
        #4*1*42 for 100 Hz signal 
        self.fc_inputs = 16*88*88*88
        
        self.conv = torch.nn.Sequential()
        self.conv.add_module("conv_1", torch.nn.Conv3d(1, 8, kernel_size=5, dilation=2))
        self.conv.add_module("BN_1", torch.nn.BatchNorm3d(8, False))
        self.conv.add_module("conv_2", torch.nn.Conv3d(8, 16, kernel_size=5))
        self.conv.add_module("BN_2", torch.nn.BatchNorm3d(16, False))

        self.fc = torch.nn.Sequential()
        self.fc.add_module("fc1", torch.nn.Linear(self.fc_inputs, output_units))
        #self.fc.add_module("relu_3", torch.nn.ReLU())
        #self.fc.add_module("dropout_3", torch.nn.Dropout3d(0.2))
        #self.fc.add_module("fc2", torch.nn.Linear(16, output_units)) #add batch_norms
        #self.fc.add_module("sig_1", torch.nn.Sigmoid()) 
        
    def forward(self,x):     
        x = self.conv.forward(x)
        x = x.view(-1, self.fc_inputs)
        return self.fc.forward(x)
    
#3DShapeNets from Princeton CVPR 2015
class conv2DNet_Princeton(nn.Module):
    def __init__(self, output_units):
        super(conv2DNet_3, self).__init__()
        
        #4*1*54 for 125 HZ 
        #4*1*42 for 100 Hz signal
        self.fc_inputs = 512*4*4*4        
        self.conv = torch.nn.Sequential()
        self.conv.add_module("conv_1", torch.nn.Conv3d(1, 48, kernel_size=6, stride=2))
        self.conv.add_module("BN_1", torch.nn.BatchNorm3d(48, False))                     
        self.conv.add_module("conv_2", torch.nn.Conv3d(48, 160, kernel_size=5, stride=2))
        self.conv.add_module("BN_2", torch.nn.BatchNorm3d(160, False))
        self.conv.add_module("conv_3", torch.nn.Conv3d(160, 512, kernel_size=4, stride=1))
        self.conv.add_module("BN_3", torch.nn.BatchNorm3d(160, False))

        self.fc = torch.nn.Sequential()
        self.fc.add_module("fc1", torch.nn.Linear(self.fc_inputs, 256))
        self.fc.add_module("relu_3", torch.nn.ReLU())
        self.fc.add_module("dropout_3", torch.nn.Dropout(0.2))
        self.fc.add_module("fc2", torch.nn.Linear(256, output_units)) #add batch_norms
        self.fc.add_module("sig_1", torch.nn.Sigmoid()) 
        
    def forward(self,x):     
        x = self.conv.forward(x)
        x = x.view(-1, self.fc_inputs)
        return self.fc.forward(x)
    
    
def conv_block_3d(in_dim,out_dim,act_fn):
    model = nn.Sequential(
        nn.Conv3d(in_dim,out_dim, kernel_size=3, stride=1, padding=1),
        nn.BatchNorm3d(out_dim),
        act_fn,
    )
    return model

def conv_trans_block_3d(in_dim,out_dim,act_fn):
    model = nn.Sequential(
        nn.ConvTranspose3d(in_dim,out_dim, kernel_size=3, stride=2, padding=1,output_padding=1),
        nn.BatchNorm3d(out_dim),
        act_fn,
    )
    return model


def maxpool_3d():
    pool = nn.MaxPool3d(kernel_size=2, stride=2, padding=0)
    return pool


def conv_block_2_3d(in_dim,out_dim,act_fn):
    model = nn.Sequential(
        conv_block_3d(in_dim,out_dim,act_fn),
        nn.Conv3d(out_dim,out_dim, kernel_size=3, stride=1, padding=1),
        nn.BatchNorm3d(out_dim),
    )
    return model    


def conv_block_3_3d(in_dim,out_dim,act_fn):
    model = nn.Sequential(
        conv_block_3d(in_dim,out_dim,act_fn),
        conv_block_3d(out_dim,out_dim,act_fn),
        nn.Conv3d(out_dim,out_dim, kernel_size=3, stride=1, padding=1),
        nn.BatchNorm3d(out_dim),
    )
    return model

class UnetGenerator_3d(nn.Module):
    def __init__(self,in_dim,out_dim,num_filter):
        super(UnetGenerator_3d,self).__init__()
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.num_filter = num_filter
        act_fn = nn.LeakyReLU(0.2, inplace=True)

        print("\n------Initiating U-Net------\n")
        
        self.down_1 = conv_block_2_3d(self.in_dim,self.num_filter,act_fn)
        self.pool_1 = maxpool_3d()
        self.down_2 = conv_block_2_3d(self.num_filter,self.num_filter*2,act_fn)
        self.pool_2 = maxpool_3d()
        self.down_3 = conv_block_2_3d(self.num_filter*2,self.num_filter*4,act_fn)
        self.pool_3 = maxpool_3d()
        
        self.bridge = conv_block_2_3d(self.num_filter*4,self.num_filter*8,act_fn)
        
        self.trans_1 = conv_trans_block_3d(self.num_filter*8,self.num_filter*8,act_fn)
        self.up_1 = conv_block_2_3d(self.num_filter*12,self.num_filter*4,act_fn)
        self.trans_2 = conv_trans_block_3d(self.num_filter*4,self.num_filter*4,act_fn)
        self.up_2 = conv_block_2_3d(self.num_filter*6,self.num_filter*2,act_fn)
        self.trans_3 = conv_trans_block_3d(self.num_filter*2,self.num_filter*2,act_fn)
        self.up_3 = conv_block_2_3d(self.num_filter*3,self.num_filter*1,act_fn)
        
        self.out = conv_block_3d(self.num_filter,out_dim,act_fn)


    def forward(self,x):
        down_1 = self.down_1(x)
        pool_1 = self.pool_1(down_1)
        down_2 = self.down_2(pool_1)
        pool_2 = self.pool_2(down_2)
        down_3 = self.down_3(pool_2)
        pool_3 = self.pool_3(down_3)
        
        bridge = self.bridge(pool_3)
        
        trans_1  = self.trans_1(bridge)
        concat_1 = torch.cat([trans_1,down_3],dim=1)
        up_1     = self.up_1(concat_1)
        trans_2  = self.trans_2(up_1)
        concat_2 = torch.cat([trans_2,down_2],dim=1)
        up_2     = self.up_2(concat_2)
        trans_3  = self.trans_3(up_2)
        concat_3 = torch.cat([trans_3,down_1],dim=1)
        up_3     = self.up_3(concat_3)
        
        #out = F.softmax(self.out(up_3), dim=0)
        out = F.sigmoid(self.out(up_3))
                        
        return out

    
class UnetGenerator_3d_softmax(nn.Module):
    def __init__(self,in_dim,out_dim,num_filter):
        super(UnetGenerator_3d_softmax,self).__init__()
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.num_filter = num_filter
        act_fn = nn.LeakyReLU(0.2, inplace=True)

        print("\n------Initiating U-Net------\n")
        
        self.down_1 = conv_block_2_3d(self.in_dim,self.num_filter,act_fn)
        self.pool_1 = maxpool_3d()
        self.down_2 = conv_block_2_3d(self.num_filter,self.num_filter*2,act_fn)
        self.pool_2 = maxpool_3d()
        self.down_3 = conv_block_2_3d(self.num_filter*2,self.num_filter*4,act_fn)
        self.pool_3 = maxpool_3d()
        
        self.bridge = conv_block_2_3d(self.num_filter*4,self.num_filter*8,act_fn)
        
        self.trans_1 = conv_trans_block_3d(self.num_filter*8,self.num_filter*8,act_fn)
        self.up_1 = conv_block_2_3d(self.num_filter*12,self.num_filter*4,act_fn)
        self.trans_2 = conv_trans_block_3d(self.num_filter*4,self.num_filter*4,act_fn)
        self.up_2 = conv_block_2_3d(self.num_filter*6,self.num_filter*2,act_fn)
        self.trans_3 = conv_trans_block_3d(self.num_filter*2,self.num_filter*2,act_fn)
        self.up_3 = conv_block_2_3d(self.num_filter*3,self.num_filter*1,act_fn)
        
        self.out = conv_block_3d(self.num_filter,out_dim,act_fn)


    def forward(self,x):
        down_1 = self.down_1(x)
        pool_1 = self.pool_1(down_1)
        down_2 = self.down_2(pool_1)
        pool_2 = self.pool_2(down_2)
        down_3 = self.down_3(pool_2)
        pool_3 = self.pool_3(down_3)
        
        bridge = self.bridge(pool_3)
        
        trans_1  = self.trans_1(bridge)
        concat_1 = torch.cat([trans_1,down_3],dim=1)
        up_1     = self.up_1(concat_1)
        trans_2  = self.trans_2(up_1)
        concat_2 = torch.cat([trans_2,down_2],dim=1)
        up_2     = self.up_2(concat_2)
        trans_3  = self.trans_3(up_2)
        concat_3 = torch.cat([trans_3,down_1],dim=1)
        up_3     = self.up_3(concat_3)
        out = F.softmax(self.out(up_3), dim=1)
                         
        return out

class UnetGenerator_3d_log_softmax(nn.Module):
    def __init__(self,in_dim,out_dim,num_filter):
        super(UnetGenerator_3d_log_softmax,self).__init__()
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.num_filter = num_filter
        act_fn = nn.LeakyReLU(0.2, inplace=True)
        
        print("\n------Initiating U-Net------\n")
        
        self.down_1 = conv_block_2_3d(self.in_dim,self.num_filter,act_fn)
        self.pool_1 = maxpool_3d()
        self.down_2 = conv_block_2_3d(self.num_filter,self.num_filter*2,act_fn)
        self.pool_2 = maxpool_3d()
        self.down_3 = conv_block_2_3d(self.num_filter*2,self.num_filter*4,act_fn)
        self.pool_3 = maxpool_3d()
        
        self.bridge = conv_block_2_3d(self.num_filter*4,self.num_filter*8,act_fn)
        
        self.trans_1 = conv_trans_block_3d(self.num_filter*8,self.num_filter*8,act_fn)
        self.up_1 = conv_block_2_3d(self.num_filter*12,self.num_filter*4,act_fn)
        self.trans_2 = conv_trans_block_3d(self.num_filter*4,self.num_filter*4,act_fn)
        self.up_2 = conv_block_2_3d(self.num_filter*6,self.num_filter*2,act_fn)
        self.trans_3 = conv_trans_block_3d(self.num_filter*2,self.num_filter*2,act_fn)
        self.up_3 = conv_block_2_3d(self.num_filter*3,self.num_filter*1,act_fn)
        
        self.out = conv_block_3d(self.num_filter,out_dim,act_fn)
    
    
    def forward(self,x):
        down_1 = self.down_1(x)
        pool_1 = self.pool_1(down_1)
        down_2 = self.down_2(pool_1)
        pool_2 = self.pool_2(down_2)
        down_3 = self.down_3(pool_2)
        pool_3 = self.pool_3(down_3)
        
        bridge = self.bridge(pool_3)
        
        trans_1  = self.trans_1(bridge)
        concat_1 = torch.cat([trans_1,down_3],dim=1)
        up_1     = self.up_1(concat_1)
        trans_2  = self.trans_2(up_1)
        concat_2 = torch.cat([trans_2,down_2],dim=1)
        up_2     = self.up_2(concat_2)
        trans_3  = self.trans_3(up_2)
        concat_3 = torch.cat([trans_3,down_1],dim=1)
        up_3     = self.up_3(concat_3)
        out = F.log_softmax(self.out(up_3), dim=1)
        
        return out
   
