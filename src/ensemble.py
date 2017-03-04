import luigi
from luigi import configuration
import os.path
import json
from src.cv_eval import CVEval

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


def values_from_conf(conf, field_name):
    path = os.path.join(
        conf.get("paths", "project_dir"),
        conf.get("paths", field_name)
    )

    with open(path, "r") as f:
        values = json.load(f)

    return values


class Ensemble(luigi.Task):
    ensemble_id = luigi.Parameter()
    output_path = luigi.Parameter()
    conf = configuration.get_conf()

    def requires(self):
        ensemble = values_from_conf(self.conf, "ensemble")
        exper = values_from_conf(self.conf, "experiment")
        ps_path = os.path.join(
            self.conf.get("paths", "project_dir"),
            self.conf.get("paths", "phyloseq")
        )

        # Need predictions for experiments we are ensembling over
        tasks = []
        for i in exper.keys():
            if i not in ensemble["exper_ids"]:
                continue

            for k in range(1, exper[i]["k_folds"] + 1):
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
