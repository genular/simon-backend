<?php

/**
 * @Author: LogIN-
 * @Date:   2018-04-03 12:22:33
 * @Last Modified by:   LogIN-
 * @Last Modified time: 2019-04-10 14:10:29
 */
namespace SIMON\Dataset;

use \Medoo\Medoo;
use \Monolog\Logger;
use \SIMON\Helpers\Helpers as Helpers;
use \SIMON\System\FileSystem as FileSystem;

class DatasetResamples {
	protected $table_name = "dataset_resamples";
	protected $database;
	protected $logger;
	protected $FileSystem;
	protected $Helpers;

	public function __construct(
		Medoo $database,
		Logger $logger,
		FileSystem $FileSystem,
		Helpers $Helpers
	) {
		$this->database = $database;
		$this->logger = $logger;
		$this->FileSystem = $FileSystem;
		$this->Helpers = $Helpers;
		// Log anything.
		$this->logger->addInfo("==> INFO: SIMON\Dataset\DatasetResamples constructed");
	}

	/**
	 * [deleteByQueueIDs description]
	 * @param  [type] $queueIDs [description]
	 * @return [type]           [description]
	 */
	public function deleteByQueueIDs($queueIDs) {
		$data = $this->database->delete($this->table_name, [
			"AND" => [
				"dqid" => $queueIDs,
			],
		]);
		return ($data->rowCount());
	}

	/**
	 * [updateStatus description]
	 * @param  [type] $resample [description]
	 * @return [type]           [description]
	 */
	public function updateStatus($resample) {

		if ($resample['isSelected'] === true) {
			$status = 0;
		} else {
			$status = 1;
		}

		$data = $this->database->update($this->table_name, [
			"status" => $status,
			"updated" => Medoo::raw("NOW()"),
		], [
			"id" => $resample['id'],
		]);

		// Returns the number of rows affected by the last SQL statement
		return ($data->rowCount());
	}

	/**
	 * [createResample description]
	 * @param  [type] $queueID  [description]
	 * @param  [type] $fileID   [description]
	 * @param  [type] $resample [description]
	 * @param  [type] $outcome  [description]
	 * @return [type]           [description]
	 */
	public function createResample($queueID, $fileID, $resample, $outcome) {

		$this->database->insert($this->table_name, [
			"dqid" => $queueID,
			"ufid" => $fileID,
			"data_source" => 1,
			"samples_total" => $resample["totalSamples"],
			"samples_training" => 0,
			"samples_testing" => 0,
			"features_total" => intval($resample["totalFeatures"]),
			"selectedOptions" => json_encode(["outcome" => $outcome, "features" => $resample["listFeatures"], "subjects" => $resample["listSamples"]]),
			"datapoints" => intval($resample["totalDatapoints"]),
			"status" => 1, // 1 - Active, activate/deactivate it based on user selection
			"servers_finished" => 0,
			"processing_time" => 0,
			"error" => Medoo::raw("NULL"),
			"created" => Medoo::raw("NOW()"),
			"updated" => Medoo::raw("NOW()"),
		]);

		$resampleID = $this->database->id();

		return ($resampleID);
	}

	/**
	 * [getDetailsByID description]
	 * @param  [type] $resampleID    [description]
	 * @param  [type] $user_id [description]
	 * @return [array]
	 */
	public function getDetailsByID($resampleID, $user_id) {
		// [><] == INNER JOIN
		$join = [
			"[><]dataset_queue" => ["dqid" => "id"],
		];
		$columns =
			[
			"dataset_resamples.id(resampleID) [Int]",
			"dataset_resamples.ufid(ufid) [Int]",
			"dataset_resamples.ufid_train(ufid_train) [Int]",
			"dataset_resamples.ufid_test(ufid_test) [Int]",
		];
		$conditions = [
			"dataset_resamples.id" => $resampleID,
			"dataset_queue.uid" => $user_id,
			"LIMIT" => 1,
		];

		$details = $this->database->get($this->table_name, $join, $columns, $conditions);

		return ($details);
	}

	/**
	 * Retrieve a list of re-samples that belong to certain Queue
	 * @param  [type] $queueID [description]
	 * @param  [type] $user_id [description]
	 * @return [type]          [description]
	 */
	public function getDatasetResamples($queueID, $user_id) {

		$sql = "SELECT dataset_resamples.dqid  			  AS queueID,
					   dataset_resamples.id               AS resampleID,
		               dataset_resamples.ufid       	  AS ufid,
		               dataset_resamples.ufid_train       AS ufid_train,
		               dataset_resamples.ufid_test        AS ufid_test,
		               dataset_resamples.data_source      AS dataSource,
		               dataset_resamples.samples_total    AS samplesTotal,
		               dataset_resamples.samples_training AS samplesTraining,
		               dataset_resamples.samples_testing  AS samplesTesting,
		               dataset_resamples.features_total   AS featuresTotal,
		               dataset_resamples.datapoints       AS datapoints,
		               dataset_resamples.status           AS status,
		               dataset_resamples.processing_time  AS processing_time,
		               dataset_resamples.error            AS error,
		               Count(models.id)                   AS modelsTotal,
		               ROUND(SUM(models.training_time))   AS model_processing_time,
		               Sum(CASE
		                     WHEN models.status > 0 THEN 1
		                     ELSE 0
		                   END)                           AS models_success
					FROM   dataset_resamples

			               	INNER JOIN dataset_queue
			                      ON dataset_resamples.dqid = dataset_queue.id
			               	INNER JOIN models
			                      ON dataset_resamples.id = models.drid
			               	INNER JOIN models_performance
			                      ON models.id = models_performance.mid
			          		INNER JOIN models_performance_variables
			                	ON models_performance.mpvid = models_performance_variables.id

					WHERE  dataset_queue.uid = :user_id
			               AND dataset_resamples.dqid = :queueID

			               GROUP BY dataset_resamples.id ORDER BY modelsTotal DESC;";

		$details = $this->database->query($sql, [
			":user_id" => $user_id,
			":queueID" => $queueID,
		])->fetchAll(\PDO::FETCH_ASSOC);

		$details = $this->Helpers->castArrayValues($details);

		return ($details);

	}

	/**
	 * Retrieve a list of re-samples that belong to certain Queue
	 * @param  [type] $resampleID [description]
	 * @param  [type] $user_id    [description]
	 * @return [type]             [description]
	 */
	public function getResampleOptions($resampleID, $user_id) {

		$sql = "SELECT
                dataset_resamples.selectedOptions AS resampleOptions,
                dataset_queue.selectedOptions AS queueOptions
                FROM dataset_resamples
                INNER JOIN dataset_queue
                    ON dataset_resamples.dqid = dataset_queue.id
                    AND dataset_queue.uid = :user_id
                WHERE dataset_resamples.id = :resampleID;";

		$details = $this->database->query($sql, [
			":user_id" => $user_id,
			":resampleID" => $resampleID,
		])->fetch(\PDO::FETCH_ASSOC);

		$details["resampleOptions"] = json_decode($details["resampleOptions"], true);
		foreach ($details["resampleOptions"]["features"] as $key => $value) {
			$details["resampleOptions"]["features"][$key] = array("remapped" => $value);
		}
		$details["queueOptions"] = json_decode($details["queueOptions"], true);

		return ($details);
	}
}
