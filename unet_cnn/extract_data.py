""" File extract_data.py used to extract the images (original training set,
# grountruth images of the training set, and testing set)

# Authors: DC""

import numpy as np
import cv2

from util import *


def extract_data(filename, num_images, train=False, resize=False, \
                 angles=np.empty(0), flip=False, imgType='data', \
                 divide_test_in_4=False, train_pixel_nb=400, \
                 resize_pixel_nb=256, pref_rotation=False):
    """ Extract the images into a 4D tensor [image index, y, x, channels].

        Input:
            filename (string): name of the folder which contains the images
            num_images (int): number of images to extract
            train (bool): True if we consider the training set, False if we consider the testing set
            resize (bool): True if the images are resized to win some computational time
            angles (numpy 1d-array): array of angles. The image set will contained the rotated versions of the image with respect to those angles.
            flip (bool): True if we consider the images and their right-flipped version
            imgType (string): 'data' if we want to extract the original image, 'label' if we extract the groundtruth
            divide_test_in_4 (bool): True if we want to split the images into 4 sub-images of dimension train_pixel_nb x train_pixel_nb
            train_pixel_nb (int): shape of a training image (we suppose that vertical shape = horizontal shape)
            resize_pixel_nb (int): number of pixels of the resized images (only useful if resize = True)
            pref_rotation (bool): True if we want to compute the angle between the horizontal and the main direction of the image, and rotate the image in consequence

        Output:
            imgs (numpy 4d-array): set of images after pre-processing depending on the input parameters
            original_pixel_nb (int): size of the original input images (before preprocessing)
            pref_angles (numpy 1d-array): each entry corresponds to the preferential angle of rotation of each input image, if pref_rotation=True. Empty if pref_rotation=False
    """
    imgs = [] # List of preprocessed images
    original_pixel_nb = 0
    pref_angles = []
    for i in range(1, num_images+1):
        if i%10==0:
            if imgType=='data':
                print('Extract original images... i =',i)
            elif imgType=='label':
                print('Extract groundtruth images... i =',i)
            else:
                print('extract_data:Error! imgType should be either data or label.')

        # Look for the files in the folder given as input, depending if it is the training or the testing images.
        if train:
            imageid = "satImage_%.3d" % i
        else:
            imageid = "test_%.1d" % i  + "/test_%.1d" % i
        image_filename = filename + imageid + ".png"

        # Preprocess each input image
        if os.path.isfile(image_filename):
            img = mpimg.imread(image_filename)
            original_pixel_nb = img.shape[0]

            # Divide the input image in 4 sub-images of size train_pixel_nb x train_pixel_nb, if requested
            if divide_test_in_4:
                croped_imgs = img_divide_in_4(img, train_pixel_nb) # divide in 4 400x400 img
            else:
                croped_imgs = [img]

            # Preprocess each sub-image
            for x in croped_imgs:
                # Resize the image if required
                if resize == True:
                    x = resize_img(x, resize_pixel_nb)
                # Added the (possibly resized) original (sub-)images to the list
                imgs.append(x)

                # If some rotation angles are specified, rotate the (sub-)images and add them to the list
                if angles.shape[0]!=0:
                    for angle in angles:
                        imgs.append(rotate_my_img(x, random=False, angle=angle))

                # Compute the preferential angle of rotation of the (sub-)image if required.
                # If this angle is not already included in the array angles, add the rotated (sub-)image to the list and keep the preferential angle in memory.
                # If it is already in the array angles, set to 0 (chosen flag) the preferential angle.
                if pref_rotation:
                    pref_angle = find_angle(x)
                    if len(np.where(angles==pref_angle)[0]) == 0:
                        imgs.append(rotate_my_img(x, random=False, angle=pref_angle))
                        # Keep in memory the angle of rotation
                        pref_angles.append(pref_angle)
                    else:
                        imgs.append(x) # it will not be used, but we need to fulfill this entry to keep track of the index
                        pref_angles.append(0)

                # If the flipping of the image is required, add the flipped version of the image into the list
                if flip:
                    imgs.append(x[:, ::-1])
        else:
            print ('extract_data:Warning! File ' + image_filename + ' does not exist')

    if imgType=='label':
        data = np.asarray(imgs)
        # If we consider the groundtruth images, the output should be an array of dimension [number of images, vertical number of pixels, horizontal number of pixels, 2],
        # where the last dimension is justified by the fact that each pixel will be either [0, 1] of [1, 0] depending on whether on the original image, it is a street pixel or not.
        imgs = [[[value_to_class(data[i][j][k]) for k in range(data.shape[2])]
                                                   for j in range(data.shape[1])]
                                                   for i in range(data.shape[0])]

    return np.asarray(imgs).astype(np.float32), original_pixel_nb, \
           np.asarray(pref_angles).astype(np.int8)
