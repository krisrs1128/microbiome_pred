import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.train import Train

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")

class Predict(luigi.Task):
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    features_conf = luigi.Parameter()
    model_conf = luigi.Parameter()
    cur_fold = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return Train(
            self.ps_path,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf,
            self.cur_fold
        )

    def run(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf,
            self.cur_fold
        ]

        x_path = pf.output_name(self.conf, specifiers_list[:4], "features_") + \
                    "-test-" + str(self.cur_fold)  + ".feather"

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "predict.R"),
                x_path,
                pf.output_name(self.conf, specifiers_list, "model_") + ".RData",
                pf.output_name(self.conf, specifiers_list, "preds_") + ".feather"
            ]
        )

        if return_code != 0:
            raise ValueError("predict.R failed")

    def output(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf,
            self.cur_fold
        ]
        result_path = pf.output_name(self.conf, specifiers_list, "preds_") + ".feather"

        return luigi.LocalTarget(result_path)
