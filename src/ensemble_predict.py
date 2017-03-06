import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.ensemble import Ensemble

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class EnsemblePredict(luigi.Task):
    ensemble_id = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return Ensemble(self.ensemble_id)

    def run(self):
        ensemble = pf.values_from_conf(self.conf, "ensemble")
        ensemble = ensemble[self.ensemble_id]
        exper = pf.values_from_conf(self.conf, "experiment")
        ensemble_properties = exper[ensemble["exper_ids"][0]]

        # Get paths to features on which to generate predictions
        specifiers_list = [
            ensemble_properties["preprocessing"],
            ensemble_properties["validation_prop"],
            ensemble_properties["k_folds"],
            ensemble_properties["features"]
        ]

        x_basename = pf.output_name(
            self.conf,
            specifiers_list,
            "features_",
            "features"
        )

        pred_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_preds_",
            "preds"
        )

        model_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_model-",
            "models"
        )

        for train_type in ["cv", "full"]:
            for test_type in ["all", "test-all-cv"]:
                return_code = subprocess.call(
                    [
                        "Rscript",
                        pf.rscript_file(self.conf, "predict.R"),
                        x_basename + "-" + test_type + ".feather",
                        model_basename + "-all-" + train_type + "_trained.RData",
                        pred_basename + "-" + train_type + "_trained-" + test_type + ".feather"
                    ]
                )

            if return_code != 0:
                raise ValueError("predict.R failed")

    def output(self):
        pred_basename = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_preds_",
            "preds"
        )

        outputs = []
        for train_type in ["cv", "full"]:
            for test_type in ["all", "test-all-cv"]:
                outputs.append(
                    luigi.LocalTarget(
                        pred_basename + "-" + train_type + "_trained-" + test_type + ".feather"
                    )
                )
        return outputs
