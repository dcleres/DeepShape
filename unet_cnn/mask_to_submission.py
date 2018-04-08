""" File mask_to_submission.py used to make the submission to Kaggle.
# Authors: DC """

import os
import numpy as np
import matplotlib.image as mpimg
import re

# assign a label to a patch
def patch_to_label(patch, foreground_threshold):
    """
        Computes the label to assign to each path by computing the mean of the
        values on the patch and comparing it to a given threshold.
        Input:
            patch (array): patch values
            foreground_threshold (float between 0 and 1): threshold value over which
                the patch is considered as foreground (ie street).
        Ouput:
            an int with value 1 if the patch is considered as foreground, 0 else.
    """
    df = np.mean(patch)
    if df > foreground_threshold:
        return 1
    else:
        return 0


def mask_to_submission_strings(image_filename, foreground_threshold):
    """Reads a single image and outputs the strings that should go into the submission file"""
    img_number = int(re.search(r"\d+", image_filename).group(0))
    im = mpimg.imread(image_filename)
    patch_size = 16
    for j in range(0, im.shape[1], patch_size):
        for i in range(0, im.shape[0], patch_size):
            patch = im[i:i + patch_size, j:j + patch_size]
            label = patch_to_label(patch, foreground_threshold)
            yield("{:03d}_{}_{},{}".format(img_number, j, i, label))


def masks_to_submission(submission_filename, *image_filenames, foreground_threshold):
    """Converts images into a submission file"""
    with open(submission_filename, 'w') as f:
        f.write('id,prediction\n')
        for fn in image_filenames[0:]:
            f.writelines('{}\n'.format(s) for s in mask_to_submission_strings(fn, foreground_threshold))
