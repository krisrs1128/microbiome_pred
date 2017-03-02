import luigi
from luigi import configuration
import subprocess

import src.utils.pipeline_funs as pf
from src.train_test_split import TrainTestSplit
from src.etl import MeltCounts

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")


def get_response_output_name(conf,
                             preprocess_conf,
                             validation_prop,
                             k_folds) :
    project_dir = conf.get("paths", "project_dir")
    id_string = preprocess_conf + \
                str(validation_prop) + \
                str(k_folds)
    return pf.processed_data_dir(
        project_dir,
        "responses_" +
        pf.hash_name(id_string)
    )


class GetResponse(luigi.Task):

    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return [
            MeltCounts(
                self.ps_path,
                self.preprocess_conf
            ),
            TrainTestSplit(
                self.ps_path,
                self.preprocess_conf,
                self.validation_prop,
                self.k_folds
            )
        ]

    def run(self):
        output_name = get_response_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        )

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "response.R"),
                self.input()[0].open("r").name,
                self.input()[1].open("r").name,
                self.ps_path,
                output_name
            ]
        )

        if return_code != 0:
            raise ValueError("response.R failed")

    def output(self):
        output_name = get_response_output_name(
            self.conf,
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds
        )

        outputs = []
        for k in ["all"] + list(range(1, int(self.k_folds) + 1)):
            for v in ["train", "test"]:
                outputs.append(
                    luigi.LocalTarget(
                        output_name + "-" + str(v) + "-" + str(k) + ".feather"
                    )
                )

        return outputs
