// Jenkinsfile for the seed-multibranch-jobs job itself.
//
// Goes in: jenkins-shared-lib/jobs/seed-pipeline.groovy
// Wired up via the Jenkins UI:
//   New Item → seed-multibranch-jobs → Pipeline → "Pipeline script from SCM"
//   SCM: Git, URL: https://github.com/<your-github-username>/jenkins-shared-lib.git
//   Script Path: jobs/seed-pipeline.groovy
//
// Skill: jenkins-job-bootstrap (~/.claude/skills/jenkins-job-bootstrap/)

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 5, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        // Re-scan if jenkins-shared-lib changes; complements webhook if you have one
        pollSCM('H/15 * * * *')
    }

    stages {
        stage('Sync Multibranch Jobs') {
            steps {
                jobDsl(
                    targets: 'jobs/seed-job.groovy',
                    // SAFETY: never delete jobs not in the manifest. Manual cleanup only.
                    removedJobAction: 'IGNORE',
                    removedViewAction: 'IGNORE',
                    // Land jobs at root, not nested in this seed job's folder
                    lookupStrategy: 'JENKINS_ROOT',
                    // Sandbox OFF: enabling sandbox requires "Authorize Project" plugin
                    // + per-job "run as specific user" config. For a single-admin
                    // homelab this is overkill — the script is admin-controlled in
                    // a private repo. Disabling sandbox needs a one-time admin
                    // approval of the script via Manage Jenkins → Script Approval.
                    sandbox: false
                )
            }
        }
    }

    post {
        success {
            echo 'seed-multibranch-jobs: complete. Check root job listing for any new pipelines.'
        }
        failure {
            echo 'seed-multibranch-jobs: FAILED. If first run, check console for "Approve" link from Script Security.'
        }
    }
}
