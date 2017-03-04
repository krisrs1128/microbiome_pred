import hashlib
import os.path
import json


def hash_name(long_name, length=15):
    long_name = long_name.encode("utf-8")
    x = int(hashlib.sha1(long_name).hexdigest(), 16) % (10 ** length)
    return str(x)


def processed_data_dir(project_dir, output_name):
    """
    Full path to melted counts output

    Args
    ----
    project_dir [str]: Path to the main project directory.
    output_name [str]: The name to save the file as.

    Returns
    -------
    output [str]: The path obtained by concatenating the project directory with
      the path to the processed data subdirectory.
    """
    return os.path.join(project_dir, "data", "processed", output_name)


def rscript_dir(project_dir):
    """
    Full path to directory containing Rscripts

    Args
    ----
    project_dir [str]: Path to the main project directory.

    Returns
    -------
    output [str]: The path obtained by concatenating the project directory with
      the path to the subdirectory containing RScripts
    """
    return os.path.join(project_dir, "src", "Rscripts")


def rscript_file(conf, script):
    """
    Full path to directory containing Rscripts

    Args
    ----
    project_dir [str]: Path to the main project directory.

    Returns
    -------
    output [str]: The path obtained by concatenating the project directory with
      the path to the subdirectory containing RScripts
    """
    project_dir = conf.get("paths", "project_dir")
    return os.path.join(rscript_dir(project_dir), script)


def output_name(conf, specifiers_list, prefix):
    project_dir = conf.get("paths", "project_dir")
    id_string = "".join([str(s) for s in specifiers_list])
    return processed_data_dir(
        project_dir,
        prefix + hash_name(id_string)
    )


def values_from_conf(conf, field_name):
    path = os.path.join(
        conf.get("paths", "project_dir"),
        conf.get("paths", field_name)
    )

    with open(path, "r") as f:
        values = json.load(f)

    return values

