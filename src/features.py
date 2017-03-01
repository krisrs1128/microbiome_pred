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


def get_features_output_name(conf,
                             preprocess_conf,
                             validation_prop,
                             k_folds,
                             features_conf):
    project_dir = conf.get("paths", "project_dir")
    id_string = preprocess_conf + \
                str(validation_prop) + \
                str(k_folds) + \
                features_conf
    return pf.processed_data_dir(
        project_dir,
        "features_" +
        pf.hash_name(id_string)
    )


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
        output_name = get_features_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf
        )

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "features.R"),
                self.features_conf,
                self.input()[0].open("r").name,
                self.input()[1].open("r").name,
                self.ps_path,
                output_name
            ]
        )

        if return_code != 0:
            raise ValueError("features.R failed")

    def output(self):
        output_name = get_features_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf
        )

        outputs = []
        for k in ["all"] + list(range(1, int(self.k_folds) + 1)):
            for v in ["training", "validation"]:
                if v == "validation" and k != "all":
                    continue

                outputs.append(
                    luigi.LocalTarget(
                        output_name + "-" + str(v) + "-" + str(k) + ".feather"
                    )
                )

        return outputs
