""" File mirror_padding.py used to extend an image with mirror boundary conditions.
# Authors:DC"""

import numpy as np

def mirror_padding(image, padding=1):
    """
        Create a mirror padding (wrap) around the image, to emulate mirror
        boundary conditions.
        Input:
            image (numpy array)
            padding (int): width of the padding around the image where mirror BC will appear.
    """

    lower_pad = np.flip(image[-padding:], 0)
    upper_pad = np.flip(image[:padding], 0)

    partial_image = np.concatenate((upper_pad, image, lower_pad), axis=0)

    right_pad = np.flip(partial_image[:,-padding:], 1)
    left_pad = np.flip(partial_image[:,:padding], 1)

    padded_image = np.concatenate((left_pad, partial_image, right_pad), axis=1)

    return padded_image

"""# usage example:
image = np.reshape(np.array(range(6)), (2,3))
padded_image = mirror_padding(image, padding=2)
print(image)
print(padded_image)"""
