import luigi
from luigi import configuration
from src.ensemble_predict import EnsemblePredict
import src.utils.pipeline_funs as pf

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


class MicrobiomePred(luigi.WrapperTask):
    conf = configuration.get_config()

    def requires(self):
        ensemble = pf.values_from_conf(self.conf, "ensemble")

        tasks = []
        for i in ensemble.keys():
            tasks.append(EnsemblePredict(i))

        return tasks


if __name__ == "__main__":
    luigi.run()
