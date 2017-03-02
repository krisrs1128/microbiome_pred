import luigi
from luigi import configuration
import os.path
import json
from src.train import Train

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

        # Read experiment configuration file
        exper_conf = os.path.join(
            self.conf.get("paths", "project_dir"),
            self.conf.get("paths", "experiment")
        )

        with open(exper_conf, "r") as f:
            exper = json.load(f)

        tasks = []
        for i in exper.keys():
            for k in range(1, exper[i]["k_folds"] + 1):
                tasks.append(
                    Train(
                        ps_path,
                        exper[i]["preprocessing"],
                        exper[i]["validation_prop"],
                        exper[i]["k_folds"],
                        exper[i]["features"],
                        exper[i]["model"],
                        str(k)
                    )
                )

        return tasks


if __name__ == "__main__":
    luigi.run()
