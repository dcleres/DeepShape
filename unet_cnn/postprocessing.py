""" File postprocessing.py used to postprocess the predicted labels for each image.
# Authors: DC"""

import numpy as np

from util import resize_img, rotate_my_img

def postprocess_test(img, resize=False, train_pixel_nb=400, divide_test_in_4=False, \
                     nb_imgs_per_img_test=1, imgType='data', angles=np.empty(0), \
                     flip=False, test_pixel_nb=608, pref_angles=np.empty(0)):
    """
        Postprocessing function to get the final predictions on the original images.
        Input:
            img (numpy array): 4d-array describing the images [number of images, vertical number of pixels, horizontal number of pixels, number of channels]
            resize (bool): True to resize back the images to their original size
            train_pixel_nb (int): shape of a training images (we suppose that vertical shape = horizontal shape)
            divide_test_in_4 (bool): True if we want to split the images into 4 sub-images of dimension train_pixel_nb x train_pixel_nb
            nb_imgs_per_img_test (int): from one test image, we have created a certain number of images that have been fed into the neural net. This corresponds to this number of images.
            imgType (string): 'data' if we are processing the image, 'label' if we are processing the groundtruth
            angles (numpy 1d-array): array of angles from which the images have been rotated before being fed to the neural net.
            flip (bool): True if we consider the images and their right-flipped version
            train_pixel_nb (int): shape of a testing images (we suppose that vertical shape = horizontal shape)
            pref_angles (numpy array): array of angles corresponding to the preferential rotation angle of each test image (if it has been computed, it is empty otherwise).

        Output:
            numpy 4d-array containing the predictions of all the (original) images for every pixel.
    """

    if divide_test_in_4:
        nb_subimg = 4
    else:
        nb_subimg = 1
    out_data_size = int(img.shape[0]/(nb_imgs_per_img_test*nb_subimg))

    if imgType=='data':
        # If we consider the images and not their label, it is enough to consider the original image, not its transormations.
        temp = img[0::nb_imgs_per_img_test]
    elif imgType=='label':
        # If we consider the predicitons, there is more work to do. First, average the predictions on all the modified (sub-)images.
        temp = np.empty([nb_subimg*out_data_size, img.shape[1], img.shape[2], img.shape[3]])

        width_central_pixels = int((img.shape[1]//np.sqrt(2))/2)
        offset = img.shape[1]//2-width_central_pixels

        for i in range(nb_subimg*out_data_size):
            flag = 0
            # Consider the predictions on the original image.
            temp[i] = img[nb_imgs_per_img_test*i]

            # Consider the predictions on all the (standardly) rotated images, if specified
            for j in range(angles.shape[0]):
                temp[i] = temp[i] \
                        + rotate_my_img(img[nb_imgs_per_img_test*i+j+1], \
                                        random=False, angle=-angles[j])

            # Consider the predictions on the preferentially rotated image, if specified
            if pref_angles.shape[0] != 0:
                flag = 1
                if pref_angles[i] != 0:
                    flag = 2
                    back_rot_img = rotate_my_img(img[nb_imgs_per_img_test*(i+1)-2], \
                                    random=False, angle=-pref_angles[i])
                    temp[i, offset:-offset, offset:-offset] = \
                            temp[i, offset:-offset, offset:-offset] \
                            + back_rot_img[offset:-offset, offset:-offset]

            # Consider the predictions on the flipped images, if specified
            if flip:
                temp[i] = temp[i] + img[nb_imgs_per_img_test*(i+1)-1,:,::-1]

            # Average all the different predictions
            if flag==2: # if there has been an extra prediction of the central pixels of the rotated image
                mask = np.zeros(temp.shape[0])
                mask[offset:-offset, offset:-offset] = 1
                denominator = (np.full(temp.shape, nb_imgs_per_img_test)-1) + mask
                temp[i] = np.divide(temp[i], denominator)
            elif flag==1: # if the rotation by the main angle was already included in angles
                temp[i] /= nb_imgs_per_img_test-1
            else: # if pref_angles is empty
                temp[i] /= nb_imgs_per_img_test
    else:
        print('postprocess_test:ERROR! imgType should be either data or label.')

    # Resize the predictions/images to the size of the original images
    if resize:
        temp = np.array([resize_img(temp[i], train_pixel_nb) for i in range(temp.shape[0])])

    # Put together the four different predictions/images for each sub-image to get back the original image/predictions
    if divide_test_in_4:
        mid = int(test_pixel_nb/2.0)
        out = np.empty([out_data_size, test_pixel_nb, test_pixel_nb, img.shape[3]])
        for i in range(out_data_size):
            out[i, :mid, :mid, :] = temp[nb_subimg*i, :mid, :mid, :]
            out[i, :mid, mid:, :] = temp[nb_subimg*i+1, :mid, -mid:, :]
            out[i, mid:, :mid, :] = temp[nb_subimg*i+2, -mid:, :mid, :]
            out[i, mid:, mid:, :] = temp[nb_subimg*i+3, -mid:, -mid:, :]
        return out
    else:
        return temp
