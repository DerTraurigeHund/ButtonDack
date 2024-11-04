# Project Setup Guide

This guide will help you set up a virtual environment and install the required libraries for this project.

## Prerequisites

- **Python 3**: Ensure you have Python 3 installed. You can verify the installation by running:
  ```bash
  python3 --version
  ```

- **pip**: Ensure you have `pip` installed. Verify with:
  ```bash
  pip3 --version
  ```

If either of these is not installed, please refer to the [Python installation guide](https://www.python.org/downloads/) and install Python along with `pip`.

## Steps to Set Up the Project

### 1. Clone the Repository (if applicable)

If this project is in a Git repository, clone it first:
```bash
git clone https://github.com/DerTraurigeHund/StreamDeck_for_iPad
cd StreamDeck_for_iPad
```


### 2. Run the Setup Script

A setup script named `setup_env.sh` is provided to automate the creation of a virtual environment and installation of dependencies. Ensure the script is executable:

```bash
chmod +x setup_env.sh
```

Run the script:

```bash
./setup_env.sh
```

This script will:
1. Create a virtual environment named `venv`.
2. Activate the virtual environment.
3. Install the required libraries listed in `requirements.txt`.
4. Deactivate the virtual environment after installation.

### 3. Activate the Virtual Environment

To activate the virtual environment, use the following command:

```bash
source venv/bin/activate
```

You should now be in the virtual environment, with all necessary libraries installed.


## Troubleshooting

- **requirements.txt not found**: Ensure the file exists in the project directory.
- **Permission issues**: If you encounter permission errors, try running the script with `sudo` (for Linux/Mac) or ensure you have sufficient privileges.

## Additional Information

For any additional setup or troubleshooting information, consult the project documentation or reach out to the project maintainer.
You can reach me via email: luis.thomas@goldstudios.de
