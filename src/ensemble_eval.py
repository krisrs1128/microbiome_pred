import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.ensemble_predict import EnsemblePredict

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class EnsembleEval(luigi.Task):
    ensemble_id = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return EnsemblePredict(self.ensemble_id)

    def run(self):
        ensemble = pf.values_from_conf(self.conf, "ensemble")
        ensemble = ensemble[self.ensemble_id]
        exper = pf.values_from_conf(self.conf, "experiment")
        properties = exper[ensemble["exper_ids"][0]]

        # Get paths to features on which to generate predictions
        specifiers_list = [
            properties["preprocessing"],
            properties["validation_prop"],
            properties["k_folds"]
        ]

        y_basename = pf.output_name(
            self.conf,
            specifiers_list,
            "responses_",
            "responses"
        )
        pred_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_preds_",
            "preds"
        )
        output_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_eval_",
            "eval"
        )

        for train_type in ["cv", "full"]:
            for test_type in ["all", "test-all-cv"]:
                return_code = subprocess.call(
                    [
                        "Rscript",
                        pf.rscript_file(self.conf, "eval.R"),
                        pred_basename + "-" + train_type + "_trained-" + test_type + ".feather",
                        y_basename + "-" + test_type + ".feather",
                        properties["metrics"],
                        output_basename + "-" + train_type + "_trained-" + test_type + ".feather",
                        properties["preprocessing"],
                        properties["features"],
                        "ensemble_" + self.ensemble_id,
                        str(properties["validation_prop"]),
                        str(properties["k_folds"]),
                        "NA"
                    ]
                )

        if return_code != 0:
            raise ValueError("eval.R failed")

    def output(self):
        output_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_eval_",
            "eval"
        )

        output_names = []
        for train_type in ["cv", "full"]:
            for test_type in ["all", "test-all-cv"]:
                output_names.append(
                    output_basename + "-" + train_type + "_trained-" + test_type + ".feather"
                )

        return [luigi.LocalTarget(s) for s in output_names]
