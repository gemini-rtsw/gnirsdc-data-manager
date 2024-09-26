import numpy as np
import matplotlib.pyplot as plt

def read_input_file(filename):
    """
    Reads the input file and returns source and destination points.

    Parameters:
        filename (str): Path to the input file.

    Returns:
        src_points (numpy.ndarray): Array of source points of shape (N, 2).
        dest_points (numpy.ndarray): Array of destination points of shape (N, 2), scaled to degrees.
    """
    src_points = []
    dest_points = []

    with open(filename, 'r') as file:
        for line_num, line in enumerate(file, start=1):
            # Strip whitespace and skip empty lines
            stripped_line = line.strip()
            if not stripped_line:
                continue
            # Split the line into parts
            parts = stripped_line.split()
            if len(parts) != 4:
                print(f"Warning: Line {line_num} does not have exactly 4 elements. Skipping.")
                continue
            try:
                x_src, y_src, x_dest, y_dest = map(float, parts)
                src_points.append([x_src, y_src])
                dest_points.append([x_dest, y_dest])
            except ValueError:
                print(f"Warning: Line {line_num} contains non-numeric data. Skipping.")
                continue

    # Apply offset to source points
#    src_offset = np.array([-19.6, 150.0])  # Default offset is (-19.6, 150.0)
    src_points = np.array(src_points)# + src_offset

    # Apply scaling to destination points to convert from mm to degrees
    scale_factor = 1.66 / 3600.0  # 1.66 mm corresponds to arcseconds; divide by 3600 to get degrees
    dest_scale = np.array([scale_factor, scale_factor])
    dest_points = np.array(dest_points) * dest_scale

    dest_offset = np.array([-3.14, 23.45])  
    dest_points = np.array(dest_points) #+ dest_offset

    return src_points, dest_points

def compute_procrustes(src_points, dest_points, apply_translation=True):
    """
    Computes the best-fit scaling, rotation, and translation to map src_points to dest_points.

    Parameters:
        src_points (numpy.ndarray): Array of source points of shape (N, 2).
        dest_points (numpy.ndarray): Array of destination points of shape (N, 2).
        apply_translation (bool): Whether to compute and apply translation.

    Returns:
        transformation_matrix (numpy.ndarray): 2x2 matrix combining scale and rotation.
        scale (float): Scale factor.
        theta (float): Rotation angle in radians.
        translation (numpy.ndarray): Translation vector of shape (1, 2).
    """
    # Compute centroids
    centroid_src = np.mean(src_points, axis=0)
    centroid_dest = np.mean(dest_points, axis=0)

    # Print centroids
    print(f"Source Centroid: {centroid_src}")
    print(f"Destination Centroid: {centroid_dest}")

    # Center the points
    src_centered = src_points - centroid_src
    dest_centered = dest_points - centroid_dest

    # Compute covariance matrix
    covariance_matrix = src_centered.T @ dest_centered

    # Singular Value Decomposition (SVD)
    U, S, Vt = np.linalg.svd(covariance_matrix)

    # Compute rotation matrix
    rotation_matrix = Vt.T @ U.T

    # Handle reflection
    if np.linalg.det(rotation_matrix) < 0:
        Vt[-1, :] *= -1
        rotation_matrix = Vt.T @ U.T

    # Compute scale
    scale = np.trace(src_centered.T @ dest_centered @ rotation_matrix) / np.trace(src_centered.T @ src_centered)

    # Compute translation
    if apply_translation:
        translation = centroid_dest - scale * (rotation_matrix @ centroid_src)
    else:
        translation = np.array([0.0, 0.0])  # No translation

    # Apply additional rotation to the transformation matrix
    final_transformation_matrix = rotation_matrix * scale

    # Update the rotation angle
    final_theta = np.arctan2(final_transformation_matrix[1, 0], final_transformation_matrix[0, 0])

    return final_transformation_matrix, scale, final_theta, translation

def plot_transformation(src_points, dest_points, transformation_matrix, translation):
    """
    Plots the original and transformed points and prints the source, destination, and transformed points.

    Parameters:
        src_points (numpy.ndarray): Array of source points of shape (N, 2).
        dest_points (numpy.ndarray): Array of destination points of shape (N, 2).
        transformation_matrix (numpy.ndarray): 2x2 combined scale and rotation matrix.
        translation (numpy.ndarray): Translation vector of shape (1, 2).
    """
    # Transform the source points using the combined transformation matrix and translation
#    transformed_points = src_points @ transformation_matrix.T + translation
#    transformation_matrix = np.array([
#        [-3.62424139562799E-05, -2.18690840336252E-05],
#        [2.16030382479371E-05, -3.68117762385558E-05]
#    ])


    transformed_points = src_points @ transformation_matrix.T + translation

    # Compute residuals
    residuals = dest_points - transformed_points

    # Compute RMSE
    rmse = np.sqrt(np.mean(np.sum(residuals**2, axis=1)))

    # Print the source, destination, transformed points, residuals, and RMSE
    np.set_printoptions(precision=6, suppress=True)
    print("\nSource Points (pixels, mm):")
    print(src_points)
    print("\nDestination Points (degrees):")
    print(dest_points)
    print("\nTransformed Points (degrees):")
    print(transformed_points)
    print("\nResiduals (Destination - Transformed) (degrees):")
    print(residuals)
    print(f"\nRoot Mean Square Error (RMSE): {rmse:.6f} degrees")

    # Plotting
    fig, ax = plt.subplots(1, 3, figsize=(24, 8))

    # Plot 1: Pixel Coordinates
    ax[0].scatter(src_points[:, 0], src_points[:, 1], marker='o', color='blue', label='Source')
    ax[0].set_title('Pixel Coordinates (mm)')
    ax[0].set_xlabel('X (mm)')
    ax[0].set_ylabel('Y (mm)')
    ax[0].invert_yaxis()
    ax[0].legend()
    ax[0].grid(True)

    # Plot 2: World Coordinates in Degrees
    ax[1].scatter(dest_points[:, 0], dest_points[:, 1], marker='o', color='green', label='Destination')
    ax[1].scatter(transformed_points[:, 0], transformed_points[:, 1], marker='x', color='red', label='Transformed')
    ax[1].set_title('World Coordinates (Degrees)')
    ax[1].set_xlabel('Right Ascension (°)')
    ax[1].set_ylabel('Declination (°)')
    ax[1].invert_xaxis()  # RA increases to the left
    ax[1].legend()
    ax[1].grid(True)

    # Plot 3: World Coordinates in Arcseconds
    dest_points_arcsec = dest_points * 3600.0  # Convert degrees to arcseconds
    transformed_points_arcsec = transformed_points * 3600.0  # Convert degrees to arcseconds
    ax[2].scatter(dest_points_arcsec[:, 0], dest_points_arcsec[:, 1], marker='o', color='green', label='Destination')
    ax[2].scatter(transformed_points_arcsec[:, 0], transformed_points_arcsec[:, 1], marker='x', color='red', label='Transformed')
    ax[2].set_title('World Coordinates (Arcseconds)')
    ax[2].set_xlabel('Right Ascension (")')
    ax[2].set_ylabel('Declination (")')
    ax[2].invert_xaxis()  # RA increases to the left
    ax[2].legend()
    ax[2].grid(True)

    plt.tight_layout()
    plt.show()

def main():
    import argparse
    import sys

    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description="Compute 2D scale, rotation, and translation matrix from point correspondences.")
    parser.add_argument('input_file', help="Path to the input file containing point correspondences.")
    parser.add_argument('--no-translate', action='store_true', help="Do not apply translation (set translation vector to [0, 0]).")

    args = parser.parse_args()

    # Read the input file
    src_points, dest_points = read_input_file(args.input_file)

    if src_points.size == 0:
        print("Error: No valid point correspondences found in the input file.")
        sys.exit(1)

    if src_points.shape != dest_points.shape:
        print("Error: Source and destination points must have the same dimensions.")
        sys.exit(1)

    # Determine whether to apply translation
    apply_translation = not args.no_translate

    # Compute transformation matrix, scale, rotation, and translation
    transformation_matrix, scale, theta, translation = compute_procrustes(src_points, dest_points, apply_translation=apply_translation)

    # Convert rotation angle from radians to degrees
    theta_degrees = np.degrees(theta)

    # Apply additional rotation of -52.6559717229396 degrees
    additional_rotation_angle = np.radians(90.0 - 52.6559717229396)
    additional_rotation_matrix = np.array([
        [np.cos(additional_rotation_angle), -np.sin(additional_rotation_angle)],
        [np.sin(additional_rotation_angle), np.cos(additional_rotation_angle)]
    ])

    
    transformation_matrix = additional_rotation_matrix @ transformation_matrix  
    '''
    scale_factor = 1.66 / 3600.0  # 1.66 mm corresponds to arcseconds; divide by 3600 to get degrees
    dest_scale = np.array([scale_factor, scale_factor])
    transformation_matrix = transformation_matrix * dest_scale
    
    translation = translation * 1.66
    '''

    # Display the results
    print(f"\nScale factor: {scale:.6f}")
    print(f"Rotation angle: {theta_degrees:.6f} degrees")
    print("Transformation matrix (Scale * Rotation):")
    print(transformation_matrix)
    print(f"Translation vector: {translation}")
    #print(f"Hotspot offset vector: {hotspot_offset}")

    # Plot the transformation and print the output
    plot_transformation(src_points, dest_points, transformation_matrix, translation)

if __name__ == "__main__":
    main()
