import luigi
from luigi import configuration
import os.path
import subprocess
import src.tasks.pipeline_funs as pf
from src.tasks.predict import Predict

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class Ensemble(luigi.Task):
    ensemble_id = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        ensemble = pf.values_from_conf(self.conf, "ensemble")
        ensemble = ensemble[self.ensemble_id]

        exper = pf.values_from_conf(self.conf, "experiment")
        ps_path = os.path.join(
            self.conf.get("paths", "project_dir"),
            self.conf.get("paths", "phyloseq")
        )

        # Need predictions for experiments we are ensembling over
        tasks = []
        for i in exper.keys():
            if i not in ensemble["exper_ids"]:
                continue

            for k in ["all", "all-cv"] + list(range(1, exper[i]["k_folds"] + 1)):
                tasks.append(
                    Predict(
                        ps_path,
                        exper[i]["preprocessing"],
                        str(exper[i]["validation_prop"]),
                        str(exper[i]["k_folds"]),
                        exper[i]["features"],
                        exper[i]["model"],
                        str(k)
                    )
                )

        return tasks

    def run(self):
        ensemble = pf.values_from_conf(self.conf, "ensemble")
        ensemble = ensemble[self.ensemble_id]

        exper = pf.values_from_conf(self.conf, "experiment")
        preds_basenames = ""
        models_basenames = ""

        # get paths to experiment results we needs in ensembling
        for i in exper.keys():
            if i not in ensemble["exper_ids"]:
                continue

            specifiers_list = [
                exper[i]["preprocessing"],
                exper[i]["validation_prop"],
                exper[i]["k_folds"],
                exper[i]["features"],
                exper[i]["model"]
            ]

            preds_basenames += pf.output_name(
                self.conf,
                specifiers_list,
                "preds_",
                "preds"
            ) + ";"
            models_basenames += pf.output_name(
                self.conf,
                specifiers_list,
                "model_",
                "models"
            ) + ";"

            # These are assumed constant over experiments, so safe to overwrite
            y_basename = pf.output_name(
                self.conf,
                specifiers_list[:3],
                "responses_",
                "responses"
            )
            k_folds = exper[i]["k_folds"]

        # Now call the ensemble script
        output_prefix = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_model-",
            "models"
        )

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "ensemble.R"),
                preds_basenames,
                models_basenames,
                y_basename,
                str(k_folds),
                output_prefix + "-all",
                self.conf.get("paths", "ensemble"),
                self.ensemble_id
            ]
        )

        if return_code != 0:
            raise ValueError("ensemble.R failed")

    def output(self):
        output_prefix = pf.output_name(
            self.conf,
            self.ensemble_id,
            "ensemble_model-",
            "models"
        )
        suffixes = [
            "-all-cv_trained.RData",
            "-all-full_trained.RData"
        ]
        return [luigi.LocalTarget(output_prefix + s) for s in suffixes]
