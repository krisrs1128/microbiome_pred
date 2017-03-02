import luigi
from luigi import configuration
import os.path
import json
from src.features import GetFeatures
from src.response import GetResponse

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
        for k in exper.keys():
            tasks.append(
                GetFeatures(
                    ps_path,
                    exper[k]["preprocessing"],
                    str(exper[k]["validation_prop"]),
                    str(exper[k]["k_folds"]),
                    exper[k]["features"]
                )
            )
            tasks.append(
                GetResponse(
                    ps_path,
                    exper[k]["preprocessing"],
                    str(exper[k]["validation_prop"]),
                   str(exper[k]["k_folds"])
                )
            )

        return tasks


if __name__ == "__main__":
    luigi.run()
