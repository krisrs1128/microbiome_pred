import luigi
from luigi import configuration
import os
from src.tasks.ensemble_eval import EnsembleEval
from src.tasks.cv_eval import CVEval
import src.tasks.pipeline_funs as pf

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class MicrobiomePred(luigi.WrapperTask):
    conf = configuration.get_config()

    def requires(self):
        ps_path = os.path.join(
            self.conf.get("paths", "project_dir"),
            self.conf.get("paths", "phyloseq")
        )

        ensemble = pf.values_from_conf(self.conf, "ensemble")

        tasks = []
        for i in ensemble.keys():
            tasks.append(EnsembleEval(i))

        exper = pf.values_from_conf(self.conf, "experiment")
        for i in exper.keys():
            for k in ["all", "all-cv"] + list(range(1, exper[i]["k_folds"])):
                tasks.append(
                    CVEval(
                        ps_path,
                        exper[i]["preprocessing"],
                        str(exper[i]["validation_prop"]),
                        str(exper[i]["k_folds"]),
                        exper[i]["features"],
                        exper[i]["model"],
                        str(k),
                        exper[i]["metrics"]
                    )
                )

        return tasks

if __name__ == "__main__":
    luigi.run()
