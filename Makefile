CD=`pwd`
DAC=$(CD)/bin/dac
PART1_TARGETS=part1/docker.dockerfile
PART2_TARGETS=part2/apache.dockerfile part2/apache8888.dockerfile part2/docker-compose.yml part2/setup-local-webroot
PART3_TARGETS=part3/datasource.tf part3/outputs.tf part3/keypair.tf part3/provider.tf part3/ec2.tf part3/sg.tf part3/docker.dockerfile
ALL=README.md build-part1 build-part2 build-part3
DOC=src/sportsref.md

default:
	@echo "Please specify a target to build"
	@echo "  make build-part1"
	@echo "  make run-part1"
	@echo "  make build-part2"
	@echo "  make run-part2"
	@echo "  make build-part3"
	@echo "  make plan-part3"
	@echo "  make apply-part3"
	@echo "  make destroy-part3"

clean:
	@rm -f *~
	@rm -rf part2/webroot
	@rm -f part3/ec2-keypair.pem
	@rm -f part3/terraform.tfstate*
	@rm -f part3/tfplan
	@rm -rf part3/.terraform*
	@rm -f $(PART1_TARGETS)
	@rm -f $(PART2_TARGETS)
	@rm -f $(PART3_TARGETS)
	@rm -f *.dockerfile
	@rm -f */*.dockerfile

.git/hooks/pre-commit: $(DOC)
	@$(DAC) -t -R $@ $< > $@
	@chmod 0755 $@

all: .git/hooks/pre-commit $(ALL)
.PHONY: all default clean

README.md: $(DOC)
	@$(DAC) -w $< > $@

part1/docker.dockerfile: $(DOC)
	@echo Creating Docker Dockerfile
	@$(DAC) -t -R $@ $< > $@

build-part1: $(PART1_TARGETS)
	@docker build -t docker:srpart1 -f part1/docker.dockerfile part1/

run-part1: build-part1
	@docker run --rm docker:srpart1

.PHONY: default build-part1 run-part1

part2/apache.dockerfile: $(DOC)
	@echo Creating Apache on port 80 Dockerfile
	@$(DAC) -t -R $@ $< > $@

part2/apache8888.dockerfile: $(DOC)
	@echo Creating Apache on port 8888 Dockerfile
	@$(DAC) -t -R $@ $< > $@

part2/docker-compose.yml: $(DOC)
	@echo Creating docker-compose.yml
	@$(DAC) -t -R $@ $< > $@

part2/setup-local-webroot: $(DOC)
	@echo Creating webroot
	@$(DAC) -t -R $@ $< > $@
	@cd part2; sh -x setup-local-webroot

build-part2: $(PART2_TARGETS)
	@docker build -t docker:srpart2a -f part2/apache.dockerfile part2/
	@docker build -t docker:srpart2b -f part2/apache8888.dockerfile part2/
	@cd part2; docker-compose build

run-part2a: build-part2
	@docker run --rm -p 8888:80 docker:srpart2a

run-part2b: build-part2
	@cd part2; docker-compose up 

.PHONY: build-part2 run-part2a run-part2b

part3/provider.tf: $(DOC)
	@$(DAC) -t -R $@ $< > $@

part3/datasource.tf: $(DOC)
	@$(DAC) -t -R $@ $< > $@
       
part3/outputs.tf: $(DOC) 
	@$(DAC) -t -R $@ $< > $@

part3/keypair.tf: $(DOC)
	@$(DAC) -t -R $@ $< > $@

part3/sg.tf: $(DOC) 
	@$(DAC) -t -R $@ $< > $@

part3/ec2.tf: $(DOC)
	@$(DAC) -t -R $@ $< > $@

part3/tfplan: build-part3
	@terraform -chdir=part3 plan -out tfplan

part3/docker.dockerfile: $(DOC)
	@echo Creating Docker Dockerfile
	@$(DAC) -t -R $@ $< > $@


build-part3: $(PART3_TARGETS)
	@terraform -chdir=part3 init
	@terraform -chdir=part3 fmt
	@terraform -chdir=part3 validate

plan-part3: part3/tfplan

apply-part3: part3/tfplan
	@terraform -chdir=part3 apply "tfplan"

destroy-part3:
	@terraform -chdir=part3 destroy

.PHONY: build-part3 plan-part3 apply-part3 destroy-part3
