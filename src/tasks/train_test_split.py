import luigi
from luigi import configuration
import subprocess

import src.tasks.pipeline_funs as pf
from src.tasks.etl import MeltCounts

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class TrainTestSplit(luigi.Task):
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return MeltCounts(self.ps_path, self.preprocess_conf)

    def run(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        ]

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "train_test_split.R"),
                self.input().open("r").name,
                pf.output_name(self.conf, specifiers_list, "cv_") + ".feather",
                self.validation_prop,
                self.k_folds
            ]
        )

        if return_code != 0:
            raise ValueError("melt_counts.R failed")

    def output(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        ]
        result_path = pf.output_name(self.conf, specifiers_list, "cv_") + ".feather"

        return luigi.LocalTarget(result_path)
