import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.train_test_split import TrainTestSplit
from src.etl import MeltCounts

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class GetFeatures(luigi.Task):

    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    features_conf = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return [
            MeltCounts(
                self.ps_path,
                self.preprocess_conf
            ),
            TrainTestSplit(
                self.ps_path,
                self.preprocess_conf,
                self.validation_prop,
                self.k_folds
            )
        ]

    def run(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf
        ]

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "features.R"),
                self.features_conf,
                self.input()[0].open("r").name,
                self.input()[1].open("r").name,
                self.ps_path,
                pf.output_name(
                    self.conf,
                    specifiers_list,
                    "features_",
                    "features"
                )
            ]
        )

        if return_code != 0:
            raise ValueError("features.R failed")

    def output(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf
        ]
        result_path = pf.output_name(
            self.conf,
            specifiers_list,
            "features_",
            "features"
        )

        outputs = [luigi.LocalTarget(result_path + "-all.feather")]
        for k in ["all-cv"] + list(range(1, int(self.k_folds) + 1)):
            for v in ["train", "test"]:
                outputs.append(
                    luigi.LocalTarget(
                        result_path + "-" + str(v) + "-" + str(k) + ".feather"
                    )
                )

        return outputs
