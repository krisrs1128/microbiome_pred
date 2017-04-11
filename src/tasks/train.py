import luigi
from luigi import configuration
import subprocess

import src.tasks.pipeline_funs as pf
from src.tasks.features import GetFeatures
from src.tasks.response import GetResponse

import logging
import logging.config
logging_conf = configuration.get_config().get("core", "logging_conf_file")
logging.config.fileConfig(logging_conf)
logger = logging.getLogger("microbiome.pred")

class Train(luigi.Task):
    ps_path = luigi.Parameter()
    preprocess_conf = luigi.Parameter()
    validation_prop = luigi.Parameter()
    k_folds = luigi.Parameter()
    features_conf = luigi.Parameter()
    model_conf = luigi.Parameter()
    cur_fold = luigi.Parameter()
    conf = configuration.get_config()

    def requires(self):
        return [
            GetFeatures(
                self.ps_path,
                self.preprocess_conf,
                self.validation_prop,
                self.k_folds,
                self.features_conf
            ),
            GetResponse(
                self.ps_path,
                self.preprocess_conf,
                self.validation_prop,
                self.k_folds
            )
        ]

    def run(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf
        ]

        x_path = pf.output_name(
            self.conf,
            specifiers_list[:4],
            "features_",
            "features"
        ) + "-train-" + str(self.cur_fold) + ".feather"

        y_path = pf.output_name(
            self.conf,
            specifiers_list[:3],
            "responses_",
            "responses"
        ) + "-train-" + str(self.cur_fold) + ".feather"

        if str(self.cur_fold) == "all":
            x_path = x_path.replace("-train", "")
            y_path = y_path.replace("-train", "")

        result_path = pf.output_name(
            self.conf,
            specifiers_list,
            "model_",
            "models"
        ) + "-" + str(self.cur_fold) + ".RData"

        return_code = subprocess.call(
            [
                "Rscript",
                pf.rscript_file(self.conf, "train.R"),
                x_path,
                y_path,
                result_path,
                self.model_conf
            ]
        )

        if return_code != 0:
            raise ValueError("train.R failed")

        project_dir = self.conf.get("paths", "project_dir")
        x_mapping = pf.processed_data_dir(project_dir, "x_mapping.txt")
        with open(x_mapping, "a") as fx:
            fx.write(",".join(specifiers_list[:4] + [self.cur_fold, x_path]) + "\n")

        y_mapping = pf.processed_data_dir(project_dir, "y_mapping.txt")
        with open(y_mapping, "a") as fy:
            fy.write(",".join(specifiers_list[:3] + [self.cur_fold, y_path]) + "\n")

        m_mapping = pf.processed_data_dir(project_dir, "m_mapping.txt")
        with open(m_mapping, "a") as fm:
            fm.write(",".join(specifiers_list + [self.cur_fold, result_path]) + "\n")

        fm.close()
        fx.close()
        fy.close()

    def output(self):
        specifiers_list = [
            self.preprocess_conf,
            self.validation_prop,
            self.k_folds,
            self.features_conf,
            self.model_conf,
        ]
        result_path = pf.output_name(
            self.conf,
            specifiers_list,
            "model_",
            "models"
        ) + "-" + str(self.cur_fold) + ".RData"

        return luigi.LocalTarget(result_path)
