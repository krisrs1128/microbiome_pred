import luigi
from luigi import configuration
import subprocess

import src.tasks.pipeline_funs as pf
from src.tasks.predict import Predict

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class CVEval(luigi.Task):
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    features_conf = luigi.Parameter()
    model_conf = luigi.Parameter()
    cur_fold = luigi.Parameter()
    eval_metrics = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return Predict(
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
            self.cur_fold,
            self.eval_metrics
        ]

        y_path = pf.output_name(
            self.conf,
            specifiers_list[:3],
            "responses_",
            "responses"
        ) + "-test-" + self.cur_fold  + ".feather"
        if self.cur_fold == "all":
            y_path = y_path.replace("-test", "")

        pred_path = pf.output_name(
            self.conf,
            specifiers_list[:-2],
            "preds_",
            "preds"
        ) + "-" + self.cur_fold + ".feather"

        output_path = pf.output_name(
            self.conf,
            specifiers_list,
            "cv_eval_",
            "eval"
        ) + ".feather"

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "eval.R"),
                pred_path,
                y_path,
                self.eval_metrics,
                output_path,
                self.preprocess_conf,
                self.features_conf,
                self.model_conf,
                self.validation_prop,
                self.k_folds,
                self.cur_fold
            ]
        )

        if return_code != 0:
            raise ValueError("eval.R failed")

    def output(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf,
            self.cur_fold,
            self.eval_metrics
        ]
        output_path = pf.output_name(
            self.conf,
            specifiers_list,
            "cv_eval_",
            "eval"
        ) + ".feather"

        return luigi.LocalTarget(output_path)
