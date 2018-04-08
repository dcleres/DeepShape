""" File layers.py used to build the neural network features, variables and layers,
and to compute the different evaluation metrics (cross entropy, F score)
# Authors: jakeret, DC"""

# Code taken and modified from the tf_unet code from https://github.com/jakeret/tf_unet
# tf_unet is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# tf_unet is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with tf_unet.  If not, see <http://www.gnu.org/licenses/>.

from __future__ import print_function, division, absolute_import, unicode_literals

import tensorflow as tf

def weight_variable(shape, stddev=0.1):
    """
        Define weight variables of the net randomly from a truncated normal distribution.
        Input:
            shape (tuple): shape of the weight variables
            stddev (float): standard deviation of the trucated normal distribution
    """
    initial = tf.truncated_normal(shape, stddev=stddev)
    return tf.Variable(initial)

def weight_variable_devonc(shape, stddev=0.1):
    """
        Define weight variables of the net randomly from a truncated normal distribution.
        Input:
            shape (tuple): shape of the weight variables
            stddev (float): standard deviation of the trucated normal distribution
    """
    return tf.Variable(tf.truncated_normal(shape, stddev=stddev))

def bias_variable(shape):
    """
        Define bias variables of the net initialized at 0.1
        Input:
            shape (tuple): shape of the biais variables
    """
    initial = tf.constant(0.1, shape=shape)
    return tf.Variable(initial)

def conv2d(x, W, keep_prob_):
    """
        Computes a 2-D convolution given 4-D input and filter tensors with
        strides 1 and 'SAME' padding, followed by a dropout.
        Input:
            x (tensor): input tensor
            W (tensor): filter tensors
            keep_prob_ (float between 0 and 1): probability to keep the nodes in the dropout
    """
    conv_2d = tf.nn.conv2d(x, W, strides=[1, 1, 1, 1], padding='SAME')
    return tf.nn.dropout(conv_2d, keep_prob_)

def deconv2d(x, W, stride):
    """
        Computes a 2-D deconvolution given 4-D input and filter tensors with 'SAME' padding.
        Input:
            x (tensor): input tensor
            W (tensor): filter tensors
            stride (int): stride of the sliding window
    """
    x_shape = tf.shape(x)
    output_shape = tf.stack([x_shape[0], x_shape[1]*2, x_shape[2]*2, x_shape[3]//2])
    return tf.nn.conv2d_transpose(x, W, output_shape, strides=[1, stride, stride, 1], padding='SAME')

def max_pool(x, n):
    """
        Performs the max pooling on the input.
        Input:
            x(tensor): input tensor
            n (int): size of the window for each dimension of the input tensor, and size of the stride.
    """
    return tf.nn.max_pool(x, ksize=[1, n, n, 1], strides=[1, n, n, 1], padding='SAME')

def crop_and_concat(x1, x2):
    """
        Reduces two tensors to the same size (the one of x2) and concatenate them.
        Input:
            x1 (tensor): first input tensor
            x2 (tensor): second input tensor
    """
    x1_shape = tf.shape(x1)
    x2_shape = tf.shape(x2)
    # offsets for the top left corner of the crop
    offsets = [0, (x1_shape[1] - x2_shape[1]) // 2, (x1_shape[2] - x2_shape[2]) // 2, 0]
    size = [-1, x2_shape[1], x2_shape[2], -1]
    x1_crop = tf.slice(x1, offsets, size)
    return tf.concat([x1_crop, x2], 3)

def pixel_wise_softmax(output_map):
    """
        Performs a softmax pixel by pixel from a neural net map called output_map.
    """
    exponential_map = tf.exp(output_map)
    evidence = tf.add(exponential_map,tf.reverse(exponential_map,[False,False,False,True]))
    return tf.div(exponential_map,evidence, name="pixel_wise_softmax")

def pixel_wise_softmax_2(output_map):
    """
        Performs a softmax pixel by pixel from a neural net map called output_map.
    """
    exponential_map = tf.exp(output_map)
    sum_exp = tf.reduce_sum(exponential_map, 3, keep_dims=True)
    tensor_sum_exp = tf.tile(sum_exp, tf.stack([1, 1, 1, tf.shape(output_map)[3]]))
    return tf.div(exponential_map,tensor_sum_exp)

def cross_entropy(y_, output_map):
    """
        Computes the cross entropy from a neural net map and the grountruth.
        Input:
            y_: exact values, groundtruth
            output_map: neural net map used to get the predictions
    """
    return -tf.reduce_mean(y_*tf.log(tf.clip_by_value(output_map,1e-10,1.0)), name="cross_entropy")

def compute_FScore(labels, predictions):
    """
        Computes the F-score of the predictions, when the groundtruth is known.
        Input:
            labels (numpy array): array containing the groundtruth
            predictions (numpy array): array containing the predicted values
    """

    # arrays with position of given number
    id_true_label = numpy.where(labels[:,0]==1)
    id_false_label = numpy.where(labels[:,0]==0)
    id_true_prediction = numpy.where(predictions[:,0]==1)
    id_false_prediction = numpy.where(predictions[:,0]==0)
    # TP = T + P where P = Positive, T = True and so on
    TP = (numpy.isin(id_true_prediction,id_true_label)== True).sum()
    FP = (numpy.isin(id_true_prediction,id_false_label)== True).sum()
    TN = (numpy.isin(id_false_prediction,id_false_label)== True).sum()
    FN = (numpy.isin(id_false_prediction,id_true_label)== True).sum()
    #print(TP,FP,TN,FN)
    precision = (TP )/(TP + FP)
    recall = (TP)/(TP + FN)
    Fscore = 2*precision*recall/(precision+recall)
    # print(precision, recall, Fscore)
    return Fscore
