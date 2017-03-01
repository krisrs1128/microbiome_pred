import luigi
from luigi import configuration
import subprocess
import os.path
import src.utils.pipeline_funs as pf

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class PhyloseqExists(luigi.ExternalTask):
    """
    Check whether the specified phyloseq object exists
    """
    ps_path = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.ps_path)


class PreprocessCounts(luigi.Task):
    """
    Preprocess the Raw Phyloseq Counts

    Read the parameters specified by the preprocessing component in the
    experiments JSON and save the preprocessed version of the phyloseq object.
    """
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return PhyloseqExists(self.ps_path)

    def run(self):
        project_dir = self.conf.get("paths", "project_dir")
        return_code = subprocess.call(
            [
                "Rscript",
                os.path.join(
                    pf.rscript_dir(project_dir),
                    "preprocess_counts.R"
                ),
                self.ps_path,
                os.path.join(project_dir, self.preprocess_conf),
                pf.processed_data_dir(
                    project_dir,
                    "preprocessed_" +
                    pf.hash_name(self.preprocess_conf) + ".RDS"
                )
            ]

        )
        if return_code != 0:
            return ValueError("preprocess_counts.R failed")

    def output(self):
        project_dir = self.conf.get("paths", "project_dir")
        output_name = pf.processed_data_dir(
           project_dir,
           "preprocessed_" +
            pf.hash_name(self.preprocess_conf) + ".RDS"
        )
        return luigi.LocalTarget(output_name)


class MeltCounts(luigi.Task):
    """
    Melt phyloseq counts

    Given the path to a phyloseq object, write a feather with the melted
    abundance matrix. This is essentially just a wrapper of melt_counts.R which
    can be used in the luigi pipeline.
    """
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return PreprocessCounts(self.ps_path, self.preprocess_conf)

    def run(self):
        project_dir = self.conf.get("paths", "project_dir")
        output_name = pf.processed_data_dir(
            project_dir,
            "melted_" +
            pf.hash_name(self.preprocess_conf) + ".feather"
        )
        return_code = subprocess.call(
            [
                "Rscript",
                os.path.join(
                    pf.rscript_dir(project_dir), "melt_counts.R"
                ),
                self.input().open("r").name,
                output_name
            ]
        )

        if return_code != 0:
            raise ValueError("melt_counts.R failed")

    def output(self):
        project_dir = self.conf.get("paths", "project_dir")
        output_name = pf.processed_data_dir(
            project_dir,
            "melted_" +
            pf.hash_name(self.preprocess_conf) + ".feather"
        )
        return luigi.LocalTarget(output_name)
