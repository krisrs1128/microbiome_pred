import luigi
from luigi import configuration
import os.path
from src.etl import MeltCounts

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
            "data",
            "raw",
            self.conf.get("paths", "phyloseq")
        )
        return MeltCounts(ps_path)

if __name__ == "__main__":
    luigi.run()
