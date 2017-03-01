import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.etl import MeltCounts

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


def get_cv_output_name(conf, preprocess_conf, validation_prop, k_folds):
    project_dir = conf.get("paths", "project_dir")
    id_string = preprocess_conf + \
                str(validation_prop) + \
                str(k_folds)
    return pf.processed_data_dir(
        project_dir,
        "cv_" +
        pf.hash_name(id_string) + ".feather"
    )


class TrainTestSplit(luigi.Task):
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return MeltCounts(self.ps_path, self.preprocess_conf)

    def run(self):
        output_name = get_cv_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        )

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "train_test_split.R"),
                self.input().open("r").name,
                output_name,
                self.validation_prop,
                self.k_folds
            ]
        )

        if return_code != 0:
            raise ValueError("melt_counts.R failed")

    def output(self):
        output_name = get_cv_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        )

        return luigi.LocalTarget(output_name)
