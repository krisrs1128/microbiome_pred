import luigi
from luigi import configuration
import subprocess
import os.path

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")

## helper-functions------------------------------------------------------------
def output_path(project_dir):
    """
    Full path to melted counts output

    Args
    ----
    project_dir [str]: Path to the main project directory.

    Returns
    -------
    output [str]: The path obtained by concatenating the project directory with
      the path to the processed data subdirectory.
    """
    return os.path.join(project_dir, "data", "processed", "m_x.feather")

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


## luigi-tasks ----------------------------------------------------------------
class PhyloseqExists(luigi.ExternalTask):
    """
    Check whether the specified phyloseq object exists
    """
    ps_path = luigi.Parameter()
    def output(self):
        return luigi.LocalTarget(self.ps_path)

class MeltCounts(luigi.Task):
    """
    Melt phyloseq counts

    Given the path to a phyloseq object, write a feather with the melted
    abundance matrix. This is essentially just a wrapper of melt_counts.R which
    can be used in the luigi pipeline.
    """
    ps_path = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return PhyloseqExists(self.ps_path)

    def run(self):
        project_dir = self.conf.get("paths", "project_dir")
        return_code = subprocess.call(
            [
                "Rscript",
                os.path.join(rscript_dir(project_dir), "melt_counts.R"),
                self.ps_path,
                output_path(project_dir)
            ]
        )
        if return_code != 0:
            raise ValueError("melt_counts.R failed")

    def output(self):
        return luigi.LocalTarget(output_path(self.conf.get("paths", "project_dir")))
